require 'aws-sdk'
require 'time-lord'

module Lita
  module Handlers
    class CodedeployStatus < Handler
      config :aws_region, default: ENV['AWS_REGION'] || 'us-east-1'
      config :aws_access_key
      config :aws_secret_access_key
      config :application_name
      config :deployment_group_name
      config :branches, required: true, type: Hash

      route(/^codedeploy-status\s*(.*?)$/, :codedeploy_status, help: {"codedeploy-status BRANCH" => "Display CodeDeploy status for most recent deployment of BRANCH"})


      def codedeploy_status(response)
        @helper = Module.new do
          def time_ago(t)
            if t
              "(#{TimeLord::Period.new(t, Time.now).in_words})"
            end
          end

          def short_instance_id(instance_id)
            instance_id.split('/')[1]
          end
        end

        branch_name = response.matches[0][0]
        if branch_name && branch_name != ''
          branch = config.branches[branch_name]
        else
          config.branches.each do |k,v|
            if v[:default]
              branch_name = k
              branch = v
            end
          end
        end


        unless deployment_done
          response.reply("Deployment watch in progress - please wait until it is done before starting a new one.")
          return
        end

        unless branch
          response.reply("Could not find branch info for branch #{branch_name}.")
          return
        end

        branch[:name] = branch_name

        log.debug "Starting deployment watch for branch #{branch[:name]}: application_name #{branch[:application_name]}, deployment_group_name #{branch[:deployment_group_name]}"

        begin
          @deployment_id = latest_deployment_id(branch[:application_name], branch[:deployment_group_name])
          @deployment_instances = get_deployment_instances

          watch_deployment(branch, response)
        rescue => e
          response.reply("Error: #{e.message}")
        end
      end

      def watch_deployment(branch, response)
        do_watch_deployment(branch, response)
        unless deployment_done
          every(10) do |timer|
            do_watch_deployment(branch, response, timer)
          end
        end
      end

      def do_watch_deployment(branch, response, timer=nil)
        begin
          update_deployment_info

          if deployment_done
            render_output(branch, response)
            timer.stop if timer
          else
            if deployment_updated
              render_output(branch, response)
            end
          end
        rescue => e
          response.reply("Error: #{e.message}")
        end
      end

      def render_output(branch, response)
        response.reply(render_template_with_helpers("codedeploy_status", [@helper], config: config,
                                                    branch: branch,
                                                    deployment_id: @deployment_id,
                                                    deployment: @deployment,
                                                    deployment_instances: @deployment_instances,
                                                    deployment_instance_status: @deployment_instance_status))
      end

      def codedeploy_api
        @aws_api ||= codedeploy_api_init
      end

      def codedeploy_api_init
        if config.aws_access_key && config.aws_secret_access_key
          Aws.config[:credentials] = Aws::Credentials.new(config.aws_access_key, config.aws_secret_access_key)
        end
        if config.aws_region
          Aws.config[:region] = config.aws_region
        end
        Aws::CodeDeploy::Client.new
      end

      def latest_deployment_id(application_name, deployment_group_name)
        codedeploy_api.list_deployments(application_name: application_name, deployment_group_name: deployment_group_name).deployments.first
      end

      def get_deployment_instances
        codedeploy_api.list_deployment_instances(deployment_id: @deployment_id).instances_list
      end

      def deployment_status
        codedeploy_api.get_deployment(deployment_id: @deployment_id)
      end

      def deployment_instance_status(instance_id)
        codedeploy_api.get_deployment_instance(deployment_id: @deployment_id, instance_id: instance_id)
      end

      def deployment_done
        @deployment == nil || @deployment.deployment_info.complete_time != nil
      end

      def deployment_updated
        @previous_instance_id != @current_instance_id ||
            @previous_instance_update != @current_instance_update
      end

      def update_deployment_info
        @deployment = deployment_status
        @deployment_instance_status = @deployment_instances.collect {|instance_id| deployment_instance_status(instance_id)}

        raise 'Unable to get deployment info' unless @deployment && @deployment_instance_status

        @previous_instance_id = @current_instance_id
        @previous_instance_update = @current_instance_update

        @deployment_instance_status.each do |status|
          if status.instance_summary.status == 'InProgress'
            @current_instance_id = status.instance_summary.instance_id
            @current_instance_update = status.instance_summary.last_updated_at
          end
        end
      end


      Lita.register_handler(self)
    end
  end
end

require 'aws-sdk'
require 'time-lord'

module Lita
  module Handlers
    class CodedeployStatus < Handler
      config :aws_region
      config :aws_access_key
      config :aws_secret_access_key
      config :application_name
      config :deployment_group_name

      route(/^codedeploy-status$/, :codedeploy_status, help: {"codedeploy-status" => "Display CodeDeploy status for most recent deployment"})


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

        begin
          @deployment_id = latest_deployment_id
          @deployment_instances = get_deployment_instances

          watch_deployment(response)
        rescue => e
          response.reply("Error: #{e.message}")
        end
      end

      def watch_deployment(response)
        do_watch_deployment(response)
        unless deployment_done
          every(10) do |timer|
            do_watch_deployment(response, timer)
          end
        end
      end

      def do_watch_deployment(response, timer=nil)
        begin
          update_deployment_info

          if deployment_done
            render_output(response)
            timer.stop if timer
          else
            if deployment_updated
              render_output(response)
            end
          end
        rescue => e
          response.reply("Error: #{e.message}")
        end
      end

      def render_output(response)
        response.reply(render_template_with_helpers("codedeploy_status", [@helper], config: config,
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

      def latest_deployment_id
        codedeploy_api.list_deployments(application_name: config.application_name, deployment_group_name: config.deployment_group_name).deployments.first
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
        @deployment.deployment_info.complete_time != nil
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

# lita-codedeploy-status

Show AWS CodeDeploy status

## Installation

Add lita-codedeploy-status to your Lita instance's Gemfile:

``` ruby
gem "lita-codedeploy-status"
```

## Configuration

It is assumed your ENV has the proper environment variables for the aws-sdk gem to function. Typically this
includes:

AWS_REGION
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

These can be overridden using the following config variables:

```ruby
config.handlers.codedeploy_status.aws_region = 'us-east-1'
config.handlers.codedeploy_status.aws_access_key = 'XYZ'
config.handlers.codedeploy_status.aws_secret_access_key = 'ABC'
```

The minumum required configuration is to declare your branches and which application_name/deployment_group_name they
point to:


```ruby
config.handlers.codedeploy_status.branches = {
      'master' => {application_name: 'App_Name', deployment_group_name: 'Production_Deployment_Group', default: true},
      'staging' => {application_name: 'App_Name', deployment_group_name: 'Staging_Deployment_Group'},
  }
```

## Usage

```codedeploy-status BRANCH``` - Show/poll for current CodeDeploy status for the application_name/deployment_group_name associated with the specified branch
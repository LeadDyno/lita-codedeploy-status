Gem::Specification.new do |spec|
  spec.name          = "lita-codedeploy-status"
  spec.version       = "0.1.0"
  spec.authors       = ["Mike Machado"]
  spec.email         = ["mike@machadolab.com"]
  spec.description   = "Show AWS CodeDeploy status"
  spec.summary       = "Show AWS CodeDeploy status"
  spec.homepage      = "https://github.com/LeadDyno/lita-codedeploy-status"
  spec.license       = "MIT"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.1"
  spec.add_runtime_dependency "aws-sdk", "~> 2"
  spec.add_runtime_dependency "time-lord", ">= 1.0.1"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
end

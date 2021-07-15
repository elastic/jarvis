Gem::Specification.new do |spec|
  spec.name          = "lita-jarvis"
  spec.version       = "0.4.0"
  spec.authors       = ["Jordan Sissel"]
  spec.email         = ["jls@semicomplete.com"]
  spec.description   = "-"
  spec.summary       = "A chatops bot used at Elastic"
  spec.homepage      = "https://github.com/elastic/jarvis"
  spec.license       = "Apache Licence version 2.0"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.7"
  spec.add_runtime_dependency "lita-slack"
  spec.add_runtime_dependency "clamp", "~> 1.0.0"
  spec.add_runtime_dependency "mustache"
  spec.add_runtime_dependency "octokit"
  spec.add_runtime_dependency "stud"
  spec.add_runtime_dependency "concurrent-ruby", "~> 1.0"
  spec.add_runtime_dependency "git", "~> 1.2.9"
  spec.add_runtime_dependency "faraday"
  spec.add_runtime_dependency "mbox"
  spec.add_runtime_dependency "cabin"
  spec.add_runtime_dependency "open4"
  spec.add_runtime_dependency "lita-hipchat"
  spec.add_runtime_dependency "faraday_middleware"
  spec.add_runtime_dependency "rfc2047"
  spec.add_runtime_dependency "gems"
  spec.add_runtime_dependency "tzinfo"
  spec.add_runtime_dependency "travis"
  spec.add_runtime_dependency "down"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "flores"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "rspec-wait"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "guard-bundler"
  spec.add_development_dependency "guard-process"
end

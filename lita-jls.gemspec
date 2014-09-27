Gem::Specification.new do |spec|
  spec.name          = "lita-jls"
  spec.version       = "0.0.1"
  spec.authors       = ["Jordan Sissel"]
  spec.email         = ["jls@semicomplete.com"]
  spec.description   = %q{Some stuff for the lita.io bot}
  spec.summary       = spec.description
  spec.homepage      = "http://example.com/"
  spec.license       = "MIT"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 3.3"
  spec.add_runtime_dependency "rugged", ">= 0"
  spec.add_runtime_dependency "cabin", ">= 0"
  spec.add_runtime_dependency "faraday", ">= 0"

  # For access to Github's api
  spec.add_runtime_dependency "octokit", ">= 0"

  # For parsing github's .patch files (mbox format)
  spec.add_runtime_dependency "mbox", ">= 0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "insist"
  spec.add_development_dependency "stud"
  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "coveralls"
end

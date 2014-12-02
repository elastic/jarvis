require "simplecov"
require "coveralls"
require "vcr"
require "lita/rspec"
require "lita-jls"

Lita.version_3_compatibility_mode = false

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start { add_filter "/spec/" }

VCR.configure do |config|
  config.cassette_library_dir = File.join(File.dirname(__FILE__), 'fixtures', 'vcr_cassettes')
  config.hook_into :webmock
  # config.debug_logger = true
end

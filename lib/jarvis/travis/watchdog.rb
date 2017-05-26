require "open-uri"
require "travis"
require "yaml"

module Jarvis module Travis
  class Watchdog
    DEFAULT_PLUGINS_URL = "https://raw.githubusercontent.com/elastic/logstash/master/rakelib/plugins-metadata.json"
    PLUGINS_CONFIG_FILE = File.join(File.dirname(__FILE__), "../../../plugins_config.yml")
    PLUGINS_CONFIG = YAML.load(File.read(PLUGINS_CONFIG_FILE))
    DEFAULT_BRANCHES = ["master"]

    def initialize
    end

    def default_plugins
      @default_plugins ||= fetch(DEFAULT_PLUGINS_URL).select { |_, v| v["default-plugins"] }.keys
    end

    def get_status
      status = {}

      default_plugins.each do |plugin_name|
        location = "logstash-plugins/#{plugin_name}"
        repo = ::Travis::Repository.find(location)
        repo.reload
        branches = branch_to_monitor(plugin_name)
        status[plugin_name] = branches.each_with_object({}) { |branch, hsh| hsh[branch] = repo.branches[branch].failed?  }
      end

      status
    end

    def extract_failures(plugins_status)
      failures = {}

      plugins_status.each do |plugin_name, status|
        status.each do |branch, failed|
          if failed
            failures[branch] ||= []
            failures[branch] << plugin_name
          end
        end
      end

      total_failures =  failures.values.collect(&:size).reduce(&:+)
      [total_failures, plugins_status.size, failures]
    end

    def execute
      plugins_status = get_status
      extract_failures(plugins_status)
    end

    def branch_to_monitor(plugin_name)
      DEFAULT_BRANCHES.dup.concat(Array(PLUGINS_CONFIG["plugin_name"])).uniq
    end

    def fetch(url)
      MultiJson.load(open(url) { |f| f.read })
    end

    def self.execute
      self.new.execute
    end

    def self.format_items(failures)
      messages = []

      failures.each do |branch, plugins|
        messages << "Failures for branch: *#{branch}*"
        messages << plugins.sort.join(", ")
      end

      messages
    end
  end
end end

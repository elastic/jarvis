require 'lita-jls/util'
require 'rubygems'
require 'open3'
require 'gems'
require 'semverly'
require 'json'

module LitaJLS
  module Reporter
    class HipChat
      def initialize(build_messages)
        @build_messages = build_messages
      end

      def format(message)
        formatted_message = []

        @build_messages.each do |build_message|
          if build_message.status == :ok
            formatted_message << " - (success) #{build_message.message}"
          else
            if build_message.full_message
              formatted_message << " - (stare) #{build_message.message} \nstacktrace: #{build_message.error || build_message.full_message}"
            else
              formatted_message << " - (stare) #{build_message.message}"
            end
          end
        end

        message.reply(formatted_message.join("\n"))
      end
    end
  end

  class BotBuilder
    include LitaJLS::Logger

    class ConfigurationError <  StandardError; end

    GEM_TO_EXCLUDE = ["logstash"].freeze

    TASKS_ORDER = ['bundle install',
                   'bundle exec rake vendor',
                   'bundle exec rspec',
                   'bundle exec rake publish_gem'].freeze

    GEM_CREDENTIALS_FILE = '~/.gem/credentials'

    attr_reader :current_path, :project_name, :ruby_version

    def initialize(path, options = {})
      @cache_commands = {}
      @current_path = File.expand_path(path)
      @project_name = File.basename(current_path)
      @ruby_version = options.fetch(:ruby_version, nil)
      @tasks_order = options[:tasks_order] || TASKS_ORDER
    end

    def is_gem?
      File.exists?(find_gemspec)
    end

    def find_gemspec
      file = [project_name, "gemspec"].join('.')
      File.join(current_path, file)
    end

    def gem_specification
      # HACK: if you are using the `real` bundler way of creating gem
      # You have to create a version.rb file containing the version number
      # and require the file in the gemspec. 
      # Ruby will cache this require and not reload it again in a load running
      # process like the hipchat bot.
      cmd = "ruby -e \"require 'json'; spec = Gem::Specification.load('#{find_gemspec}'); results = { :name => spec.name, :version => spec.version }.to_json;puts results\""
      results = JSON.parse(execute_command_with_ruby(cmd).stdout)

      return OpenStruct.new(results)
    end

    def publishable?
      if is_gem?
        return !GEM_TO_EXCLUDE.include?(gem_specification.name)
      else
        return false
      end
    end

    def run_successfully?(task_result)
      logger.debug("Check if run run_successfully", :exit_code => task_result.status.inspect, :task_result => task_result.inspect)
      task_result.status.success?
    end 

    def execution_report(task_result)
      if run_successfully?(task_result)
        report_ok(task_result.cmd, task_result.stdout)
      else
        report_error(task_result.cmd, task_result.stdout, task_result.strderr)
      end
    end

    def cache_command(cmd, options = {})
      @cache_commands[cmd] ||= execute_command(cmd, options)
    end

    def report_error(message, full_message = nil, error = nil)
     OpenStruct.new(:status => :error, :message => message, :full_message => full_message, :error => error)
    end

    def report_ok(message, full_message = nil)
     OpenStruct.new(:status => :ok, :message => message, :full_message => full_message)
    end

    def fetch_last_released_version(name)
      # Assume you have correctly configured the ~/gem/credentials file
      credentials_file = File.expand_path(GEM_CREDENTIALS_FILE)

      if File.exist?(credentials_file)
        response = Gems.versions(name)
        if response != 'This rubygem could not be found.'
          return response.first.fetch('number', nil)
        else
          return nil
        end
      else
        raise ConfigurationError.new("Missing rubygems credentials in #{credentials_file}")
      end
    end

    def local_version
      SemVer.parse(gem_specification.version.to_s)
    end

    def rubygems_version
      rubygems_version = fetch_last_released_version(project_name)
      
      if rubygems_version.nil?
        return SemVer.new(0, 0, 0)
      else 
        return SemVer.parse(rubygems_version)
      end
    end

    def execute_command_with_ruby(cmd)
      Dir.chdir(current_path) do
        Bundler.with_clean_env do
          environment_variables = {}

          if ruby_version
            if using_rvm?
              cmd = "rvm #{ruby_version} do #{cmd}"
            elsif using_rbenv?
              raise ConfigurationError.new('RBENV is currently not supported')
            end
          end

          return cache_command(cmd, environment_variables)
        end
      end
    end

    def execute_command(cmd, environment_variables = {})
      logger.debug("Running command", :cmd => cmd, :path => current_path)
      Open3.popen3(environment_variables, cmd, :chdir => current_path) do |input, stdout, strderr, thr|
        return OpenStruct.new(:stdout => stdout.read,
                              :status => thr.value,
                              :strderr => strderr.read,
                              :cmd => cmd)
      end
    end

    def using_rvm?
      run_successfully?(cache_command('which rvm'))
    end

    def using_rbenv?
      run_successfully?(cache_command('which rbenv'))
    end

    def run_tasks
      messages = []

      @tasks_order.each do |task|
        result = execute_command_with_ruby(task)
        messages << execution_report(result)
        break unless run_successfully?(result)
      end
      messages
    end

    def build
      messages = []

      if is_gem?
        if publishable?
          if local_version < rubygems_version
            logger.debug("Remote version is higher on rubygems, we dont do anything")

            messages << report_error("Higher version on rubygems (#{rubygems_version}) than the local version (#{local_version}), see http://rubygems.org/gems/#{project_name}")
          elsif local_version == rubygems_version
            logger.debug("Same version on rubygems", :local_version => local_version, :rubygems_version => rubygems_version)

            messages << report_error("Local version and rubygems version are the same (#{local_version}|#{rubygems_version}), see http://rubygems.org/gems/#{project_name}")
          else
            logger.debug("Start the build process")

            messages.concat(run_tasks)

            if local_version == rubygems_version
              messages << report_ok("version on rubygems match local version, published #{local_version} see http://rubygems.org/gems/#{project_name}")
            else
              messages << report_error("versions on rubygems doesn't match see http://rubygems.org/gems/#{project_name}")
            end
          end
        else
          messages << report_error("#{project_name} is blacklisted, you cannot deploy it with this tool.")
        end
      else
        messages << report_error("#{project_name} doesn't have a gemspec")
      end

      messages
    end
  end
end

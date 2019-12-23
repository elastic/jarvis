require "jarvis/error"
require "shellwords"
require "bundler"
require "open4"
require "tmpdir"

module Jarvis
  class SubprocessFailure < ::Jarvis::Error ; end
  JRUBY_VERSION = "9.1.14.0"

  def self.execute(args, logger, directory = nil, env = {})
    logger.info("Running command", :args => args)
    env = parse_env_string(env) if env.is_a?(String)
    # We have to wrap the command into this block to make sure the current command use his 
    # defined set of gems and not jarvis gems.
    with_dir(directory) do # Bundler.with_clean_env do
      pid, stdin, stdout, stderr = if directory || env.any?
                                     cd_rvm_args = [
                                         "cd #{Shellwords.shellescape(directory)}",
                                         ". #{rvm_path}/scripts/rvm",
                                         "echo PWD; pwd",
                                         "rvm use #{JRUBY_VERSION}; rvm use"
                                     ]
                                     cd_rvm_args << Array(args).join(' ')
                                     wrapped = [ 'env', '-' ]
                                     wrapped.concat env_to_shell_lines(execute_env.merge(env))
                                     wrapped.concat [ 'bash', '-c', cd_rvm_args.join('; ') ]
                                     Open4::popen4(*wrapped)
                                   else
                                     Open4::popen4(*args)
                                   end
      stdin.close
      logger.pipe(stdout => :info, stderr => :error)
      _, status = Process::waitpid2(pid)
      raise SubprocessFailure, "subprocess failed with code #{status.exitstatus}" unless status.success?
    end
  end

  class << self

    private

    def with_dir(directory, &block)
      if directory.nil?
        Dir.mktmpdir(&block)
      else
        yield directory
      end
    end

    def rvm_path
      ENV['rvm_path'] || '~/.rvm'
    end

    def execute_env
      [ 'PATH', 'HOME', 'SSH_AUTH_SOCK' ].map do |var|
        ENV[var] ? [ var, ENV[var] ] : nil
      end.compact.to_h
    end

    def env_to_shell_lines(env)
      env.map { |var, val| "#{var}=#{Shellwords.shellescape(val)}" }
    end

    def parse_env_string(str)
      str.scan(/\w+=\w+/).map { |s| s.split('=') }.to_h
    end

  end
end

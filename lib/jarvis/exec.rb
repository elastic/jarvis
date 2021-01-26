require "jarvis/error"
require "jarvis/env_utils"
require "open4"

module Jarvis
  extend EnvUtils

  class SubprocessFailure < ::Jarvis::Error ; end
  JRUBY_VERSION = "9.1.14.0"

  def self.execute(args, directory = nil, env = {}, logger = self.logger)
    logger.info("Running command", :args => args) if logger
    env = parse_env_string(env) if env.is_a?(String)

    wrap_args_with_env = lambda do |args|
      if env.any?
        wrapped_args = [ 'env', '-' ]
        wrapped_args.concat env_to_shell_lines(execute_env.merge(env))
        wrapped_args.concat [ 'bash', '-c', args.join('; ') ]
        wrapped_args
      else
        args
      end
    end

    # We have to wrap the command into this block to make sure the current command use his 
    # defined set of gems and not jarvis gems.
    pid, stdin, stdout, stderr = if directory
                                   cd_rvm_args = [
                                       "cd #{shell_escape(directory)}",
                                       ". #{rvm_path}/scripts/rvm",
                                       "echo PWD; pwd",
                                       "rvm use #{JRUBY_VERSION}; rvm use"
                                   ]
                                   cd_rvm_args << Array(args).join(' ')
                                   Open4::popen4 *wrap_args_with_env.(cd_rvm_args)
                                 else
                                   Open4::popen4 *wrap_args_with_env.(args)
                                 end
    stdin.close
    logger.pipe(stdout => :info, stderr => :error) if logger
    _, status = Process::waitpid2(pid)
    raise SubprocessFailure, "subprocess failed with code #{status.exitstatus}" unless status.success?
  end

  def self.logger
    Thread.current[:logger]
  end

  class << self

    private

    def rvm_path
      ENV['rvm_path'] || '~/.rvm'
    end

    def execute_env
      [ 'PATH', 'HOME', 'SSH_AUTH_SOCK' ].map do |var|
        ENV[var] ? [ var, ENV[var] ] : nil
      end.compact.to_h
    end

  end
end

require "jarvis/error"
require "shellwords"
require "bundler"

module Jarvis
  class SubprocessFailure < ::Jarvis::Error ; end
  JRUBY_VERSION = "9.1.14.0"

  def self.execute(args, logger, directory=nil)
    logger.info("Running command", :args => args)
    # We have to wrap the command into this block to make sure the current command use his 
    # defined set of gems and not jarvis gems.
    # Bundler.with_clean_env do
      pid, stdin, stdout, stderr = if directory
                                     wrapped = ["env",
                                                "-",
                                                "PATH=#{ENV["PATH"]}",
                                                "HOME=#{ENV["HOME"]}",
                                                "SSH_AUTH_SOCK=#{ENV["SSH_AUTH_SOCK"]}",
                                                "bash",
                                                "-c",
                                                "cd #{Shellwords.shellescape(directory)};. ~/.rvm/scripts/rvm; echo PWD; pwd; rvm use #{JRUBY_VERSION}; rvm use; #{args}"]
                                     Open4::popen4(*wrapped)
                                   else
                                     Open4::popen4(*args)
                                   end
      stdin.close
      logger.pipe(stdout => :info, stderr => :error)
      _, status = Process::waitpid2(pid)
      raise SubprocessFailure, "subprocess failed with code #{status.exitstatus}" unless status.success?
    # end
  end
end

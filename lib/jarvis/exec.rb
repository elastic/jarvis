require "jarvis/error"
require "shellwords"

module Jarvis
  class SubprocessFailure < ::Jarvis::Error ; end
  JRUBY_VERSION = "1.7.22"

  def self.execute(args, logger, directory=nil)
    logger.info("Running command", :args => args)
    pid, stdin, stdout, stderr = if directory
       wrapped = ["env", "-", "PATH=#{ENV["PATH"]}", "HOME=#{ENV["HOME"]}", "bash", "-c", "cd #{Shellwords.shellescape(directory)};. ~/.rvm/scripts/rvm; echo PWD; pwd; rvm use #{JRUBY_VERSION}; rvm use; #{args}"]
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

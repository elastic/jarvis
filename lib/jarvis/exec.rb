require "jarvis/error"
require "open4"

module Jarvis
  class SubprocessFailure < ::Jarvis::Error ; end

  def self.execute(args, logger)
    logger.info("Running command", :args => args)
    pid, stdin, stdout, stderr = Open4::popen4(*args)
    stdin.close
    logger.pipe(stdout => :info, stderr => :error)
    _, status = Process::waitpid2(pid)
    raise SubprocessFailure, "subprocess failed with code #{status.exitstatus}" unless status.success?
  end
end

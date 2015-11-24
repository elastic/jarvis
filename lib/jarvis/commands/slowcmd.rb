require "clamp"
require "i18n"
require "jarvis/thread_logger"

module Jarvis module Command class SlowCommand < Clamp::Command
  def execute
    5.times do |i|
      ::Jarvis::ThreadLogger.log("Step #{i}")
      sleep 1
    end
  end
end end end

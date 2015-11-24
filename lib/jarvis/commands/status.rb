require "clamp"
require "i18n"
require "jarvis/thread_logger"

module Jarvis module Command class Status < Clamp::Command
  def execute
    Jarvis::ThreadLogger.state.each_with_index do |(thread,state),i|
      puts "#{i}: #{state}"
    end
  end
end end end

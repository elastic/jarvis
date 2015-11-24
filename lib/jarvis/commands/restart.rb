require "clamp"

module Jarvis module Command class Restart < Clamp::Command
  def execute
    puts "brb... restarting."
    exec($0)
  end
end end end

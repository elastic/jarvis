require "clamp"

module Jarvis module Command class Bounce < Clamp::Command
  def execute
    puts "Bouncing..."
    exec($0)
  end
end end end

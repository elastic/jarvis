require "clamp"
require "jarvis/location_times"

module Jarvis module Command class Teamtime < Clamp::Command
  banner "List the current time in the team locations"

  def execute
    puts Jarvis::LocationTimes.new.to_a.join($/)
  end

end end end

require "clamp"
require "jarvis/cla"
require "jarvis/patches/i18n"
require "jarvis/github/review_search"
require "jarvis/travis/watchdog"

module Jarvis module Command class Plugins < Clamp::Command
  banner "Get travis status for the default plugins"

  def execute
    total, failures = ::Jarvis::Travis::Watchdog.execute

    if total  == 0
      puts "Good job, all default plugins are green! :green_heart:"
    else
      messages = [ "Oops, We have currently *#{total}* plugins jobs failing :sadbazpanda:", ]
      messages.concat(::Jarvis::Travis::Watchdog.format_items(failures))
      messages.each { |message| puts message }
    end
  end
end end end

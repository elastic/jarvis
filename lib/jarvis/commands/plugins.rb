require "clamp"
require "jarvis/cla"
require "jarvis/patches/i18n"
require "jarvis/github/review_search"
require "jarvis/travis/watchdog"

module Jarvis module Command class Plugins < Clamp::Command
  banner "Get travis status for the default plugins"

  def execute
    total_failures, total_plugins, failures = ::Jarvis::Travis::Watchdog.execute

    if total_failures == 0
      puts "Good job, all default plugins are green! :green_heart:"
    else
      messages = [ "Oops, We have currently have *#{total_failures}* plugins jobs failing :sadbazpanda: (#{total_plugins} plugins checked)" ]
      messages.concat(::Jarvis::Travis::Watchdog.format_items(failures))
      messages.each { |message| puts message }
    end
  end
end end end

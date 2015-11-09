require "jarvis/commands/merge"
require "jarvis/commands/bounce"
require "jarvis/commands/cla"
require "jarvis/mixins/fancy_route"

module Lita
  module Handlers
    class Jarvis < Handler
      extend ::Jarvis::Mixins::FancyRoute

      on(:loaded) do |*args|
        #p :connection => args
        #require "pry"
        #binding.pry
      end

      fancy_route("restart", ::Jarvis::Command::Bounce, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("merge", ::Jarvis::Command::Merge, :command => true)
      fancy_route("cla", ::Jarvis::Command::CLA, :command => true)

      Lita.register_handler(self)
    end
  end
end

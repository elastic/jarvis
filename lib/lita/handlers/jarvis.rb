require "jarvis/commands/merge"
require "jarvis/commands/bounce"
require "jarvis/commands/cla"
require "jarvis/mixins/fancy_route"

module Lita
  module Handlers
    class Jarvis < Handler
      extend ::Jarvis::Mixins::FancyRoute
      config :cla_url
      config :organization

      fancy_route("restart", ::Jarvis::Command::Bounce, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("merge", ::Jarvis::Command::Merge, :command => true, :flags => {
        "--committer-email" => ->(request) { request.user.metadata["git-email"] || raise(::Jarvis::UserProfileError, "Missing user setting `git-email` for user #{request.user.name}") },
        "--committer-name" => ->(request) { request.user.name },
      })
      fancy_route("cla", ::Jarvis::Command::CLA, :command => true, :flags => {
        "--cla-url" => ->(_) { config.find { |c| c.name == :cla_url }.value },
      })

      Lita.register_handler(self)
    end
  end
end

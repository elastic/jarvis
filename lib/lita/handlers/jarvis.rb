require "jarvis/commands/merge"
require "jarvis/commands/bounce"
require "jarvis/commands/cla"
require "jarvis/commands/publish"
require "jarvis/mixins/fancy_route"

module Lita
  module Handlers
    class Jarvis < Handler
      extend ::Jarvis::Mixins::FancyRoute
      config :cla_url
      config :github_token
      config :organization

      fancy_route("restart", ::Jarvis::Command::Bounce, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("merge", ::Jarvis::Command::Merge, :command => true, :flags => {
        "--committer-email" => ->(request) { request.user.metadata["git-email"] || raise(::Jarvis::UserProfileError, "Missing user setting `git-email` for user #{request.user.name}") },
        "--committer-name" => ->(request) { request.user.name },
        "--github-token" => ->(_) { config.find { |c| c.name == :github_token }.value || raise(::Jarvis::Error, "Missing this setting in lita_config.rb: config.handlers.jarvis.github_token") }
      })
      fancy_route("cla", ::Jarvis::Command::CLA, :command => true, :flags => {
        "--cla-url" => ->(_) { config.find { |c| c.name == :cla_url }.value || raise(::Jarvis::Error, "Missing this setting in lita_config.rb: config.handlers.jarvis.cla_url") },
      })
      fancy_route("publish", ::Jarvis::Command::Publish, :command => true)

      Lita.register_handler(self)
    end
  end
end

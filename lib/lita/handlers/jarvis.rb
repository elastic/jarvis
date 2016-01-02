require "jarvis/commands/merge"
require "jarvis/commands/status"
require "jarvis/commands/restart"
require "jarvis/commands/slowcmd"
require "jarvis/commands/cla"
require "jarvis/commands/publish"
require "jarvis/commands/teamtime"
require "jarvis/mixins/fancy_route"
require "jarvis/thread_logger"

module Lita
  module Handlers
    class Jarvis < Handler
      extend ::Jarvis::Mixins::FancyRoute
      config :cla_url
      config :github_token
      config :organization

      on(:loaded) do
        ::Jarvis::ThreadLogger.setup
      end

      fancy_route("restart", ::Jarvis::Command::Restart, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("status", ::Jarvis::Command::Status, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("slowcmd", ::Jarvis::Command::SlowCommand, :command => true)
      fancy_route("merge", ::Jarvis::Command::Merge, :command => true, :flags => {
        "--committer-email" => ->(request) { request.user.metadata["git-email"] || raise(::Jarvis::UserProfileError, "Missing user setting `git-email` for user #{request.user.name}") },
        "--committer-name" => ->(request) { request.user.name },
        "--github-token" => ->(_) { config.find { |c| c.name == :github_token }.value || raise(::Jarvis::Error, "Missing this setting in lita_config.rb: config.handlers.jarvis.github_token") }
      })
      fancy_route("cla", ::Jarvis::Command::CLA, :command => true, :flags => {
        "--cla-url" => ->(_) { config.find { |c| c.name == :cla_url }.value || raise(::Jarvis::Error, "Missing this setting in lita_config.rb: config.handlers.jarvis.cla_url") },
      })
      fancy_route("publish", ::Jarvis::Command::Publish, :command => true)
      fancy_route("teamtime", ::Jarvis::Command::Teamtime, :command => true)

      Lita.register_handler(self)
    end
  end
end

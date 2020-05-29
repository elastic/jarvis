require 'jarvis/github'
require "jarvis/commands/merge"
require "jarvis/commands/old_merge"
require "jarvis/commands/status"
require "jarvis/commands/restart"
require "jarvis/commands/slowcmd"
require "jarvis/commands/cla"
require "jarvis/commands/publish"
require "jarvis/commands/teamtime"
require "jarvis/commands/plugins"
require "jarvis/commands/run"
require "jarvis/mixins/fancy_route"
require "jarvis/thread_logger"
require "jarvis/commands/review"
require "jarvis/github/review_search"
require "travis"
require "date"

module Lita
  module Handlers
    class Jarvis < Handler
      extend ::Jarvis::Mixins::FancyRoute

      config :cla_url
      config :github_token
      config :organization

      on(:loaded) do
        # Set github token
        ::Jarvis::Github.client(config.github_token)
        ::Jarvis::ThreadLogger.setup

        # Use github token to get a travis token
        Travis.github_auth(config.github_token)

        every(60*60) { review_search(robot) }
        # only run on Mondays, check every day what day is it
        every(24*60*60) { travis_watchdog(robot) if Date.today.monday? }
      end

      def travis_watchdog(robot)
        total_failures, total_plugins, failures = ::Jarvis::Travis::Watchdog.execute
        return if total_failures == 0

        messages = [ "Oops, We have currently have *#{total_failures}* plugins jobs failing :sadbazpanda: (#{total_plugins} plugins checked)" ]
        messages.concat(::Jarvis::Travis::Watchdog.format_items(failures))

        send_messages(room_target, messages)
      end

      def room_target
        @target_room ||= Lita::Room.find_by_name("logstash")
        @target ||= Lita::Source.new(room: @target_room)
      end

      def review_search(robot)
        total, items = ::Jarvis::Github::ReviewSearch.execute
        return if total == 0

        messages = []
        messages << "There are #{total} items needing PR review. Consider reviewing one of these please :)"
        messages.concat ::Jarvis::Github::ReviewSearch.format_items(items)
        send_messages(room_target, messages)
      end

      def send_messages(target, messages)
        messages.each do |message|
          robot.send_messages(@target, message)
          # Weirdly, slack displays messages out of order unless you do this. They must have a race
          # this only happens sometimes
          sleep 0.1
        end
      end

      fancy_route("restart", ::Jarvis::Command::Restart, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("status", ::Jarvis::Command::Status, :command => true, :pool => ::Jarvis::WorkPool::ADMINISTRATIVE)
      fancy_route("slowcmd", ::Jarvis::Command::SlowCommand, :command => true)
      fancy_route("merge", ::Jarvis::Command::Merge, :command => true, :flags => {
        "--committer-email" => ->(request) { request.user.metadata["git-email"] || raise(::Jarvis::UserProfileError, "Missing user setting `git-email` for user #{request.user.name}") },
        "--committer-name" => ->(request) { request.user.name }
      })
      fancy_route("oldmerge", ::Jarvis::Command::OldMerge, :command => true, :flags => {
        "--committer-email" => ->(request) { request.user.metadata["git-email"] || raise(::Jarvis::UserProfileError, "Missing user setting `git-email` for user #{request.user.name}") },
        "--committer-name" => ->(request) { request.user.name }
      })
      fancy_route("cla", ::Jarvis::Command::CLA, :command => true, :flags => {
        "--cla-url" => ->(_) { config.find { |c| c.name == :cla_url }.value || raise(::Jarvis::Error, "Missing this setting in lita_config.rb: config.handlers.jarvis.cla_url") },
      })
      fancy_route("publish", ::Jarvis::Command::Publish, :command => true)
      fancy_route("teamtime", ::Jarvis::Command::Teamtime, :command => true)

      # These are the same thing, but its expected people will use 
      # 'reviews' as a zero-arity to get a list of all reviews
      # and 'review PR_URL' to submit a PR
      fancy_route("reviews", ::Jarvis::Command::Review, :command => true)
      fancy_route("review", ::Jarvis::Command::Review, :command => true)
      fancy_route("plugins", ::Jarvis::Command::Plugins, :command => true)

      fancy_route("run", ::Jarvis::Command::Run, :command => true)
      fancy_route("exec", ::Jarvis::Command::Run, :command => true)

      Lita.register_handler(self)
    end
  end
end

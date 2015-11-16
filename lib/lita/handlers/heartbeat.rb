require "securerandom"
require "jarvis/commands/ping"
require "concurrent"
require "stud/interval"
require "time"

module Lita
  module Handlers

    # This handler exists because sometimes Hipchat's connection will simply
    # die or go stale and the bot will never notice.
    #
    # The goal is to have the bot periodically ping itself through chat and
    # restart if chat appears dead.
    class Heartbeat < Handler

      # This key unique to each run of Lita/Jarvis.
      HEARTBEAT_KEY = SecureRandom.uuid
      HEARTBEAT_INTERVAL = 60 # seconds
      HEARTBEAT_TIMEOUT = 180 # seconds

      # Initial assumed "last heartbeat time" is start time of the program
      LastHeartBeat = ::Concurrent::AtomicReference.new(Time.now.utc)

      route(/^heartbeat (\S+) (\d+(?:\.\d+)?)/, :heartbeat, command: true)
      route(/^ping\s*$/, :ping, :command => true)

      on(:loaded) do |*args|
        #if robot.config.adapter.any?
        if robot.config.adapters.respond_to?(:hipchat)
          puts "Starting chat health checker"
          Thread.new { self.class.heartbeat_loop(robot) }
          Thread.new { self.class.health_check_loop(robot) }
        else
          puts "No Lita adapter is configured. Chat health checker is disabled! This is OK only if the adapter is Shell. The rest of the time (production?) you will want this"
        end
      end

      def self.heartbeat_loop(robot)
        # Periodically send a heartbeat via chat to ourselves to verify that the actual chat system is alive.
        Stud.interval(HEARTBEAT_INTERVAL) { send_heartbeat(robot) }
      rescue => e
        puts "Heartbeat loop died: #{e.class}: #{e}"
      end

      def self.send_heartbeat(robot)
        robot.send_message(robot.name, "heartbeat #{HEARTBEAT_KEY} #{Time.now.to_f}")
      end

      def self.health_check_loop(robot)
        Stud.interval(HEARTBEAT_TIMEOUT) { health_check(robot) }
      rescue Exception => e
        puts "Health check loop died: #{e}"
      end

      def self.health_check(robot)
        last = LastHeartBeat.get
        age = Time.now - last
        if age > HEARTBEAT_TIMEOUT
          puts "Last heartbeat was #{age} seconds ago; expiration time is #{HEARTBEAT_TIMEOUT}. Aborting..."

          # Restart
          exec($0)
        end
      rescue Exception => e
        puts "Health check loop died: #{e.class}: #{e}"
      end

      def heartbeat(response)
        key = response.match_data[1]
        time = Time.at(response.match_data[2])
        now = Time.now

        if key != HEARTBEAT_KEY
          response.reply("Invalid heartbeat key")
          return
        end

        # Make sure the heartbeat isn't too old
        age = now - time
        if age > HEARTBEAT_TIMEOUT
          puts "Received old heartbeat (#{age} seconds). Ignoring"
          return
        end

        LastHeartBeat.set(now.utc)
      end

      def ping(response)
        response.reply(I18n.t("lita.handlers.jarvis.ping response", :last_heartbeat => LastHeartBeat.get.iso8601))
      end

      Lita.register_handler(self)
    end
  end
end

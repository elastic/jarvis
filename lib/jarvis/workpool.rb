require "concurrent"
require "jarvis/error"

module Jarvis class WorkPool
  ADMINISTRATIVE = :ADMINISTRATIVE
  NORMAL = :NORMAL

  class InvalidWorkPoolName < Jarvis::Error; end

  class << self
    INITIALIZER = Mutex.new

    # Provide a singleton instance of WorkPool
    #
    # We don't use `include Singleton` because that disables `WorkPool.new` and
    # makes this class very difficult to test. Practically, I don't want a
    # global/singleton workpool anyway and this singleton instance only exists
    # until we don't need it.
    def instance
      INITIALIZER.synchronize do
        @instance ||= self.new
      end
    end

    def fetch(name)
      instance.fetch(name)
    end

    def post(name, &block)
      fetch(name).post(&block)
    end
  end

  def initialize
    # TODO(sissel): Move this to a module.
    @pools = {
      ADMINISTRATIVE => Concurrent::ThreadPoolExecutor.new(
        max_threads: 1,
        max_queue: 1,
        fallback_policy: :abort
      ),
      NORMAL => Concurrent::ThreadPoolExecutor.new(
        max_threads: 5,
        max_queue: 1,
        fallback_policy: :abort
      )
    }

    @pools.freeze
  end

  # Get a pool by name.
  def fetch(name)
    @pools.fetch(name)
  rescue KeyError
    raise InvalidWorkPoolName, "No such work pool `#{name.inspect}`"
  end

  def post(name, &block)
    fetch(name).post(&block)
  end
end end

require "concurrent"

class WorkPool
  ADMINISTRATIVE = :ADMINISTRATIVE
  NORMAL = :NORMAL

  class InvalidWorkPoolName < StandardError; end

  class << self
    def setup_singleton
      @singleton = self.new
      nil
    end

    def fetch(name)
      @singleton.fetch(name)
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
end

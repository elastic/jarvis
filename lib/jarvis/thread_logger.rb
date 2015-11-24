require "cabin"

module Jarvis module ThreadLogger
  class State
    def initialize
      @state = {}
      @lock = Mutex.new
    end

    def <<(hash)
      @lock.synchronize do
        @state[Thread.current] = hash
      end
    end

    def get
      @lock.synchronize do
        @state.clone
      end
    end
  end

  def self.setup
    if @state.nil?
      @state = State.new
      cabin.subscribe(@state)
    end
  end

  def self.log(message, data={})
    cabin.log(message, data)
  end

  def self.state
    return @state.get
  end

  private
  def self.cabin
    Cabin::Channel.get(self)
  end
end end

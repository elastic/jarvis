module Jarvis class Defer
  def initialize
    @deferred = []
  end

  def do(&block)
    @deferred << block
  end

  def run
    @deferred.each do |block|
      block.call
    end
  end
end end

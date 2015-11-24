require "flores/random"
require "jarvis/thread_logger"
require "concurrent"

describe Jarvis::ThreadLogger do
  before :all do
    described_class.setup
  end

  context "with multiple threads" do
    let(:threads) { Flores::Random.integer(0..10) }
    let(:latch) { Concurrent::CountDownLatch.new(threads) }
    before do
      threads.times.each do |i|
        Thread.new do 
          described_class.log("Hello #{i}")
          latch.count_down
          sleep(10)
        end
      end
    end
    it "should track threads independently" do
      # Wait for all threads to have logged something
      latch.wait
      expect(described_class.state.keys.size).to be == threads
    end
  end

  context "when log is invoked" do
    let(:message) { Flores::Random.text(0..1000) }
    let(:key) { Flores::Random.text(1..10) }
    let(:value) { Flores::Random.text(1..10) }

    it "should set the state for the current thread" do
      described_class.log(message, { key => value })
      expect(described_class.state[Thread.current][:message]).to be == message
      expect(described_class.state[Thread.current][key]).to be == value
    end
  end
end

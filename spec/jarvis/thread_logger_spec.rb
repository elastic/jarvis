require "flores/random"
require "jarvis/thread_logger"

describe Jarvis::ThreadLogger do
  before :all do
    described_class.setup
  end

  context "with multiple threads" do
    before do
      Thread.new { described_class.log("Hello") }.join
      Thread.new { described_class.log("World") }.join
    end
    it "should track threads independently" do
      expect(described_class.state.keys.size).to be == 2
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

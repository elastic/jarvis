require "jarvis/workpool"
require "rspec/wait"

describe ::Jarvis::WorkPool do
  subject { described_class.new }

  describe "#fetch" do
    [ 1234, "invalid", "administrative", "", nil, false, true ].each do |name|
      context "with #{name.inspect} (of type #{name.class})" do
        it "raises Jarvis::WorkPool::InvalidWorkPoolName for an invalid pool name" do
          expect { subject.fetch(name) }.to raise_error(::Jarvis::WorkPool::InvalidWorkPoolName)
        end
      end
    end

    [::Jarvis::WorkPool::ADMINISTRATIVE, ::Jarvis::WorkPool::NORMAL].each do |name|
      context "with WorkPool::#{name}" do
        it "should be successful " do
          expect { subject.fetch(::Jarvis::WorkPool::ADMINISTRATIVE) }.not_to raise_error
        end
      end
    end
  end

  describe "#post" do
    [::Jarvis::WorkPool::ADMINISTRATIVE, ::Jarvis::WorkPool::NORMAL].each do |pool|
      context "on the #{pool} pool" do
        context "and when the pool is not full" do
          let(:queue) { Queue.new }
          let(:value) { 1 }
          it "should execute the block" do
            subject.post(pool) { queue.push(value) }
            wait(1).for { queue.pop(true) rescue nil }.to eq(value)
          end
        end

        context "and when the pool is full" do
          let(:value) { 1 }

          let(:pool_size) { subject.fetch(pool).max_length + subject.fetch(pool).max_queue }

          before do
            # fill pool with blocked workers...
            pool_size.times do
              subject.post(pool) { sleep(60) }
            end
          end

          it "should reject with an exception" do
            expect do
              subject.post(pool) { nil }
            end.to raise_error(Concurrent::RejectedExecutionError)
          end
        end
      end
    end

    context "on ADMINISTRATIVE when NORMAL is full" do
      let(:normal) { subject.fetch(::Jarvis::WorkPool::NORMAL) }
      let(:value) { 1 }

      let(:normal_pool_size) { normal.max_length + normal.max_queue }

      before do
        # fill pool with blocked workers...
        normal_pool_size.times do
          subject.post(::Jarvis::WorkPool::NORMAL) { sleep(60) }
        end
      end

      it "should succeed in posting" do
        expect do
          subject.post(::Jarvis::WorkPool::ADMINISTRATIVE) { nil }
        end.not_to raise_error
      end
    end
  end
end

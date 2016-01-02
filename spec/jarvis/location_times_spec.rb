require "jarvis/location_times"

describe Jarvis::LocationTimes do
  let(:utc) { Time.new(2016, 1, 8, 16, 30, 00).utc }

  subject { described_class.new(utc).to_a }

  context "when an array is generated" do
    it "the first entry is berlin" do
      expect(subject[0]).to eq("       Berlin Fri 05:30:00 PM")
    end

    it "the second entry is london/lisbon" do
      expect(subject[1]).to eq("London/Lisbon Fri 04:30:00 PM")
    end

    it "the third entry is montreal" do
      expect(subject[2]).to eq("     Montreal Fri 11:30:00 AM")
    end

    it "the fourth entry is minneapolis" do
      expect(subject[3]).to eq("  Minneapolis Fri 10:30:00 AM")
    end

    it "the fifth entry is mountain view" do
      expect(subject[4]).to eq("Mountain View Fri 08:30:00 AM")
    end

  end
end

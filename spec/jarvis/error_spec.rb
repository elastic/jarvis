require "jarvis/error"

describe ::Jarvis::Error do
  it "subclasses StandardError" do
    expect(subject).to be_kind_of(StandardError)
  end
end

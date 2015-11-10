require "jarvis/cla"
require "flores/random"

# because URI.escape is broken and doesn't escape @ or other characters...
require "cgi" 

describe Jarvis::CLA do

  let(:user) { CGI.escape(Flores::Random.text(10)) }
  let(:password) { CGI.escape(Flores::Random.text(10)) }
  let(:host) { "example.com" }
  let(:path) { "/example" }

  let(:cla_uri) { 
    URI::Generic.build(scheme: "https",
                       userinfo: [user, password].join(":"),
                       host: host,
                       path: path)
  }

  let(:response) do
     double("faraday response")
  end

  let(:connection) do
    double("Faraday::Connection")
  end

  before do
    allow(response).to receive(:body).and_return(json_response)
    allow(connection).to receive(:basic_auth).with(user, password)
    allow(connection).to receive(:get).with(cla_uri.path, kind_of(Hash)).and_return(response)
    allow(Faraday).to receive(:new).and_return(connection)
  end

  shared_examples_for "a cla check" do |bool, status, message|
    let(:message) { message }
    let(:json_response) {
      JSON.dump("status" => status, "message" => message)
    }

    subject { Jarvis::CLA.check(cla_uri.to_s, "example/repo", 1234) }

    describe "#ok?" do
      it "should return #{bool}" do
        expect(subject.ok?).to eq(bool)
      end
    end

    describe "message" do
      it "should return the message given by the CLA api call" do
        expect(subject.message).to eq(message)
      end
    end
  end

  context "when a CLA check fails" do
    it_behaves_like "a cla check", false, "failure", "some failure message"
  end
  context "when a CLA check succeeds" do
    it_behaves_like "a cla check", true, "success", "some success message"
  end
end

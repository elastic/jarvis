require "jarvis/github/pull_request"

describe Jarvis::GitHub::PullRequest do
  describe "#parse" do
    context "with a valid url" do
      let(:url) { "https://github.com/foo/bar/pull/123" }

      it "succeeds" do
        expect { described_class.parse(url) }.not_to raise_error
        pr = described_class.parse(url)
        expect(pr.organization).to be == "foo"
        expect(pr.project).to be == "bar"
        expect(pr.number).to be == "123"
      end
    end

    context "with an invalid url" do
      let(:urls) do
        [
          "https",
          "https://github.com",
          "https://github.com/foo/bar",
          "https://github.com/foo/bar/123",
          "https://github.com/foo/bar/issues/123",
          "https://github.com/foo/bar/issue/123",
          "https://github.com/foo/bar/pull/abcd",
        ]
      end

      it "fails" do
        urls.each do |url|
          expect { described_class.parse(url) }.to raise_error(Jarvis::GitHub::PullRequest::InvalidURL)
        end
      end
    end
  end
end

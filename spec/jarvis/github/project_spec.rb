require "jarvis/github/project"

describe Jarvis::GitHub::Project do
  describe "#parse" do
    context "with a valid url" do
      let(:urls) do
        [ 
          "https://github.com/foo/bar",
          "https://github.com/foo/bar/123",
          "https://github.com/foo/bar/issues/123",
          "https://github.com/foo/bar/issue/123",
          "https://github.com/foo/bar/pull/abcd",
        ]
      end

      it "succeeds" do
        urls.each do |url|
          expect { described_class.parse(url) }.not_to raise_error
          project = described_class.parse(url)
          expect(project.organization).to be == "foo"
          expect(project.name).to be == "bar"
        end
      end
    end

    context "with an invalid url" do
      let(:urls) do
        [
          "https",
          "https://github.com",
        ]
      end

      it "fails" do
        urls.each do |url|
          expect { described_class.parse(url) }.to raise_error(Jarvis::GitHub::Project::InvalidURL)
        end
      end
    end
  end
end

require "spec_helper"
require "insist"
require "stud/temporary"
require "rugged"
require "fileutils"

describe Lita::Handlers::Jls, :lita_handler => true do
  it do
    messages = [
      "merge https://github.com/foo/bar/pull/123 bar",
      "merge https://github.com/user/foo/pull/123 bar 1.x master",
      "merge https://github.com/elasticsearch/fancypants/pull/123 bar",
      "merge https://github.com/some-test/another-thing/pull/123 bar baz fizz",
      "merge? https://github.com/some-test/another-thing/pull/123 bar fancy-pants",
    ]
    messages.each do |m|
      routes(m).to(:merge)
    end
  end

  context "#merge", :network => true do
    it "should reply successfully if the merge works" do
      send_message("merge? https://github.com/jordansissel/this-is-only-a-test/pull/1 master")
      insist { replies.last } == "(success) Merging was successful jordansissel/this-is-only-a-test#1 into: master.\n(but I did not push it)"
    end

    it "should properly handle long commit messages"
  end
end

if ENV["DEBUG"]
  logger = Cabin::Channel.get
  logger.level = :debug if ENV["DEBUG"]
end

module Fixture
  class Util
    include LitaJLS::Util
    public(:gitdir, :clone_at)

    def workdir
      return @workdir if @workdir
      @workdir = Stud::Temporary.directory("lita-jls-testing")
    end
  end
end

#module Stud::Temporary
  #alias_method :directory_orig, :directory
  #def directory(*args)
    #r = directory_orig(*args)
    #puts r => caller[0]
    #r
  #end
#end

describe LitaJLS::Util do
  subject do
    Fixture::Util.new
  end

  after do
    FileUtils.rm_rf(subject.workdir)
  end

  context "#gitdir" do
    let(:dir) { subject.gitdir("whatever") }
    after { Dir.rmdir(dir) }
    it "should be a string" do
      insist { dir }.is_a?(String)
    end
    it "starts with the workdir" do
      insist { dir } =~ Regexp.new("^" + Regexp.escape(subject.workdir))
    end
  end

  context "#clone_at" do
    let(:url) { Stud::Temporary.directory("lita-jls-testing") }
    let(:repo) { "example" }

    before do
      insist { url } =~ /lita-jls-testing/ # just in case.
      Rugged::Repository.init_at(url)
    end

    after do
      FileUtils.rm_rf(url)
    end

    it "should clone" do
      subject.clone_at(url, repo)
      insist { File }.directory?(repo)
      insist { File }.directory?(File.join(repo, ".git"))
      reject { Rugged::Repository.new(repo) }.nil?
    end
  end

end

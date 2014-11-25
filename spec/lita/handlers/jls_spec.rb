require "spec_helper"
require "insist"
require "stud/temporary"
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
      is_expected.to route_command(m).to(:merge)
    end
  end

  it "routes `(tableflip)` to :tableflip" do
    is_expected.to route_command("(tableflip)").to(:tableflip)
    
  end

  it "routes `publish` to :publish" do
    is_expected.to route_command("publish https://github.com/foo/bar").with_authorization_for(:logstash).to(:publish)
  end

  context "#merge", :network => true do
    before do
      original_git = subject.method(:git)
      allow(subject).to receive(:git).with(any_args) do |gitdir, *args|
        # Ignore any 'git push' attempts
        if args[0] == "push" # git("push", ...)
          nil
        else
          original_git.call(gitdir, *args)
        end
      end
    end

    it "should reply successfully if the merge works" do
      allow(subject).to receive(:github_issue_label) { nil }
      expect(subject).to receive(:github_issue_label).with("jordansissel/this-is-only-a-test", 1, [])

      send_command("merge https://github.com/jordansissel/this-is-only-a-test/pull/1 master")
      insist { replies.last } == "(success) jordansissel/this-is-only-a-test#1 merged into: master"
    end

    it "should properly handle long commit messages" do
      send_command("merge https://github.com/jordansissel/this-is-only-a-test/pull/4 master")
      insist { replies.last } == "(success) jordansissel/this-is-only-a-test#4 merged into: master"

      repodir = subject.instance_eval { gitdir("this-is-only-a-test") }
      Dir.chdir(repodir) do
        log = `git log --format="%B" -n 1 HEAD`.chomp
        insist { log } == "One two three four five six seven eight.

Nine ten eleven.

Twelve?
* Thirteen
* Fourteen

Fixes #4
"
      end
    end
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

    def workdir(*args)
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
    end

    after do
      FileUtils.rm_rf(url)
    end

    it "should clone" do
      subject.clone_at(url, repo)
      insist { File }.directory?(repo)
      insist { File }.directory?(File.join(repo, ".git"))
    end
  end

  context "#github_issue_label" do
    let(:issue) do
      expect(subject.github_client).to receive(:add_labels_to_an_issue).with("#{user}/#{project}", pr.to_i, labels)
      github_issue_label("jordansissel/this-is-only-a-test", 1, [ "one", "two", "three" ])
    end
  end

  context "#workdir" do
    it "should return the same value on multiple invocations" do
      expected = subject.workdir("foo")
      5.times do
        insist { subject.workdir("foo") } == expected
      end
    end
  end
end

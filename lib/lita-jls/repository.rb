require 'lita-jls/util'

module LitaJLS
  class Repository
    include LitaJLS::Util
    include LitaJLS::Logger

    REMOTE = 'origin'

    def initialize(parsed_url)
      @parsed_url = parsed_url
    end

    def clone
      clone_at(@parsed_url.git_url, git_path)
      git(git_path, "am", "--abort") if unfinished_rebase?
    end

    def unfinished_rebase?
      File.directory?(".git/rebase-apply")
    end

    def git_path
      @git_path ||= gitdir(@parsed_url.project)
    end
    
    def switch_branch(branch)
      logger.info("Switching branches", :branch => branch, :repo => git_path)

      git(git_path, "checkout", branch)
      git(git_path, "reset", "--hard", "#{REMOTE}/#{branch}")
      git(git_path, "pull", "--ff-only")
    end
  end
end

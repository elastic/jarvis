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
    
    def switch_branch(branch, create_new=false)
      if create_new
        logger.info("Creating and switching branches", :branch => branch, :repo => git_path)
        git(git_path, "checkout", "-b", branch)
        git(git_path, "reset", "--hard", "#{REMOTE}/master")
      else
        logger.info("Switching branches", :branch => branch, :repo => git_path)
        git(git_path, "checkout", branch)
        git(git_path, "reset", "--hard", "#{REMOTE}/#{branch}")
        git(git_path, "pull", "--ff-only")
      end
    end

    def git_patch(patch_file)
      raise "Previous patch apply had failed. Please resolve it before continuing" if File.directory?(".git/rebase-apply")
      git(git_path, "am", "--3way", patch_file)
    end

    def delete_local_branch(branch, ignore_error=false)
      begin
        git(git_path, "branch", "-D", branch)
      rescue => e
        raise e unless ignore_error
     end
    end
  end
end

require "jarvis/workpool"

module Jarvis module Mixins module PoolDelegate
  def pool_delegate(pool_name, &callback)
    # Create a curried call to pool_execute that will accept 1 argument (the request)
    method(:pool_execute).to_proc.curry(3).call(pool_name, callback)
  end

  def pool_execute(pool_name, callback_proc, request)
    pool = ::Jarvis::WorkPool.fetch(pool_name)
    pool.post do
      # TODO(sissel): Track active commands so that debugging/inspection of
      #   active tasks can occur.
      # TODO(sissel): Redirect $stdout and $stderr?
      begin
        callback_proc.call(request)
      rescue ::Jarvis::UserProfileError => e
        request.reply(t("user profile error", :user => request.user.mention_name, :class => e.class, :message => e.message))
      rescue => e
        # TODO(sissel): Mark this job as failed
        request.reply(t("unhandled exception", :class => e.class, :message => e.message))
        request.reply(e.backtrace.join("\n"))
      end
      # TODO(sissel): Mark this job as complete. (Once we have job/command tracking)
    end
  rescue Concurrent::RejectedExecutionError => e
    request.reply(t("rejected execution", :pool => pool_name))
  rescue => e
    request.reply(t("unhandled exception", :class => e.class, :message => e.message))
  end
end end end

require "jarvis/workpool"

module Jarvis module Mixins module PoolDelegate
  def pool_delegate(pool_name, &callback)
    lambda do |request|
      begin
        pool = WorkPool.fetch(pool_name)
        pool.post do
          # TODO(sissel): Note what command is being executed and at what time.
          # TODO(sissel): Redirect $stdout and $stderr
          begin
            callback.call(request)
          rescue => e
            # TODO(sissel): Mark this job as failed
            request.reply(t("unhandled exception", :exception => e))
            request.reply(e.backtrace.join("\n"))
          end
          # TODO(sissel): Mark this job as complete.
        end
      rescue Concurrent::RejectedExecutionError => e
        request.reply(t("rejected execution", :pool => pool_name))
      rescue => e
        request.reply(t("unhandled exception", :exception => e))
      end
    end
  end
end end end

require "clamp"
require "jarvis/workpool"
require "jarvis/clamp_delegate"
require_relative "./pool_delegate"

module Jarvis module Mixins module FancyRoute
  include ::Jarvis::Mixins::PoolDelegate

  def fancy_route(pattern, handler=nil, options={}, &block)
    if handler.ancestors.include?(Clamp::Command)
      options[:help] = { pattern => handler.description || "#{pattern} #{handler.derived_usage_description}" }
    end

    handler = fancy_handler(handler, &block)

    # Turn a string "foo" into a regexp /^foo(\s|$)/
    pattern = Regexp.new("^#{Regexp.escape(pattern)}(\\s|$)") if pattern.is_a?(String)

    # Default to the NORMAL workpool
    pool = options.fetch(:pool, WorkPool::NORMAL)

    # Invoke the normal Lita route method to setup our new fancy route. :)
    route(pattern, options, &pool_delegate(pool, &handler))
  end

  def fancy_handler(handler, &block)
    if handler.nil?
      raise "Nothing to route to - no block or handler given for #{regexp} route." if block.nil?

      # Use the block as the handler instead.
      handler = block
    end

    case handler
    when Proc
      # nothing needed to be done
    when Symbol
      # nothing needed to be done
    when Class
      if handler.ancestors.include?(::Clamp::Command)
        handler = ::Jarvis::ClampDelegate.delegate(handler)
      end
    else
      raise "Unsupported handler type #{handler.class} (#{handler.inspect})"
    end

    handler
  end
end end end

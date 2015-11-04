require "clamp"
require "shellwords"

module Jarvis module ClampDelegate
  # Delegate a Lita route to a Clamp::Command class.
  #
  # This method will return a Proc that is intended for use as a Lita route callback
  # 
  # For example:
  #
  #     route(/^foo/, :command => true, &Jarvis::ClampDelegate.delegate(Foo)
  #
  # The 'foo' command, when invoked via the Lita bot, will pass the whole
  # message body into the Foo clamp command as if it were run via the command
  # line.
  def self.delegate(command_class)
    if !command_class.ancestors.include?(Clamp::Command)
      raise ArgumentError, "Cannot delegate to `#{command_class}` because it is not a subclass of Clamp::Command"
    end
    callback(command_class)
  end

  private
  def self.callback(command_class)
    lambda do |request|
      name, *args = Shellwords.shellsplit(request.message.body)
      cmd = command_class.new(name)

      inject_methods(cmd, request)

      begin
        cmd.run(args)
      rescue ::Clamp::UsageError => e
        cmd.puts(["Error: #{e}", cmd.help].join("\n"))
      rescue ::Clamp::HelpWanted => e
        cmd.puts(cmd.help)
      end
      nil
    end
  end

  def self.inject_methods(obj, request)
    # Override `puts` and `p` calls from within `obj` to cause them to reply
    # instead of printing to stdout.
    obj.define_singleton_method(:puts) do |message|
      request.reply(message)
    end
    obj.define_singleton_method(:p) do |message|
      request.reply(message.inspect)
    end
  end
end end

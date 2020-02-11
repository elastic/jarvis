require "shellwords"

module Jarvis module EnvUtils

  module_function

  def env_to_shell_lines(env)
    env.map { |var, val| "#{var}=#{Shellwords.shellescape(val)}" }
  end

  def parse_env_string(str)
    str.scan(/\w+=[^\s]+/).map { |s| s.split('=') }.to_h
  end

  def shell_escape(path)
    Shellwords.shellescape(path)
  end

  class Handler
    def self.call(env, **processors)
      new(env).call(processors)
    end

    attr_reader :env

    def initialize(env)
      @env = env.is_a?(String) ? EnvUtils.parse_env_string(env) : env
    end

    def call(processors)
      env.map do |key, val|
        if processor = processors[key.to_sym]
          val = processor.call(val)
        end
        [key, val]
      end.to_h
    end
  end
end end

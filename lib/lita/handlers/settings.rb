module Lita module Handlers class Settings < Handler
  # set user some-key some-value
  route(/^user\s+get\s+(\S+)\s+(.*)\s*$/, :command => true, :help => {"user set <key> <value>" => t("help.user set")}) do |request|
    _, key, value, *_ = request.match_data.to_a
    request.user.metadata[key] = value
    request.user.save
    request.reply(t("user profile updated", :user => request.user.name, :key => key))
  end

  # user get some-key
  route(/^user\s+get\s+(\S+)\s*$/, :command => true, :help => {"user get <key>" => t("help.user get")}) do |request|
    _, key, *_ = request.match_data.to_a
    value = request.user.metadata[key]
    if value
      request.reply(t("response.user profile get", :user => request.user.name, :key => key, :value => value))
    else
      request.reply(t("response.user profile key not set", :user => request.user.name, :key => key))
    end
  end
 
  # clear user some-key
  route(/^user\s+clear\s+(\S+)\s*$/, :command => true, :help => {"user clear <key>" => t("help.user clear")}) do |request|
    _, key, *_ = request.match_data.to_a
    request.user.metadata.delete(key)
    request.user.save
    request.reply(t("response.user profile clear", :user => request.user.name, :key => key))
  end

  route(/^user\s+get\s*$/, :command => true, :help => {"user get" => t("help.user get")}) do |request|
    text = request.user.metadata.collect { |k,v| "#{k} = #{v}" }.join("\n")
    if text.empty?
      request.reply(t("response.empty user profile"))
    else
      request.reply(text)
    end
  end

  Lita.register_handler(self)
end end end


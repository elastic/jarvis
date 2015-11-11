module Lita module Handlers class Settings < Handler
  # set user some-key some-value
  route(/^set\s+user\s+(\S+)\s+(.*)\s*$/, :command => true, :help => {"set user <key> <value>" => t("set user")}) do |request|
    _, key, value, *_ = request.match_data.to_a
    request.user.metadata[key] = value
    request.user.save
    request.reply(t("user profile updated", :user => request.user.name, :key => key))
  end

  # get user some-key
  route(/^get\s+user\s+(\S+)\s*$/, :command => true, :help => {"get user <key>" => t("get user")}) do |request|
    _, key, *_ = request.match_data.to_a
    value = request.user.metadata[key]
    if value
      request.reply(t("user profile get", :user => request.user.name, :key => key, :value => value))
    else
      request.reply(t("user profile key not set", :user => request.user.name, :key => key))
    end
  end

  Lita.register_handler(self)
end end end


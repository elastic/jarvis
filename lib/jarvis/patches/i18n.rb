require "i18n"
# If I don't explicitely set this in the code and require the I get an exception like this:
# `I18n::InvalidLocale: :en` is not a valid locale, This doesn't happen with lita?
I18n.config.available_locales = :en

I18n.exception_handler = lambda do |exception, locale, key, options|
  "Something went wrong with the `I18n.translate`,
  please verify your keys or string, exception: #{exception.inspect}, 
  locale: #{locale}, key: #{key}, options: #{options.inspect}"
end

# `I18n.exception_handler` will only catch `MissingTranslation` and not missing interpolation,
# but you can override it if you go through the `I18.config`, not sure why this is not exposed.
# We have to return a nicer error, because the thread could glob the error and make debugging really hard.
I18n.config.missing_interpolation_argument_handler = lambda do |missing_key, provided_hash, string|
  "Something went wrong with the `I18n.translate`,
  missing_key: #{missing_key}, provided_hash: #{provided_hash}, string: #{string}"
end

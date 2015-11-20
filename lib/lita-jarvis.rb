require "lita"

Thread.abort_on_exception = true
Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/handlers/jarvis"
require "lita/handlers/heartbeat"
require "lita/handlers/settings"

Lita::Handlers::Jarvis.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)

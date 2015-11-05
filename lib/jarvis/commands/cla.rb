require "clamp"
require "jarvis/cla"
require "i18n"

module Jarvis module Command class CLA < Clamp::Command
  def t(key, params={})
    I18n.t("lita.handlers.jarvis.#{key}", params)
  end

  banner "Run a CLA check on a PR"

  option "--cla-url", "CLA_URL", "The URL for the CLA check service", :required => true, :environment_variable => "JARVIS_CLA_URL"

  parameter "URL", "The PR URL to check"

  def execute
    *_, user, project, _, pr = url.split("/")
    cla = ::Jarvis::CLA.check(cla_url, "#{user}/#{project}", pr.to_i)
    if cla.ok?
      puts t("cla.success", :project => "#{user}/#{project}", :pr => pr, :message => cla.message)
    else
      puts t("cla.failure", :project => "#{user}/#{project}", :pr => pr, :message => cla.message)
      return 1
    end
  rescue => e
    puts "An error occurred: #{e.class} - #{e}\n" + e.backtrace.join("\n")
  end
end end end

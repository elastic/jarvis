require "jarvis/patches/i18n.rb"

describe I18n do
  it "should not raise an exception but instead return a friendly string" do
    expect { I18n.t("lita.handlers.test", :user => "jarvis") }.not_to raise_error
  end
end

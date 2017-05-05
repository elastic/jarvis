module Jarvis; module Github; module ReviewSearch
  def self.execute
    search_base = "assignee:\"elasticsearch-bot\" state:open"
    
    searches = [
      search_base + " org:logstash-plugins",
      search_base + " repo:elastic/logstash"
    ]

    results = searches.map {|q| ::Jarvis::Github.client.search_issues(q) }

    total = results.reduce {|r| r[:total_count] }
    items = results.flat_map {|r| r[:items]}

    [total, items]
  end

  def self.format_items(items)
    items.map do |item|
      url = URI.parse(item[:html_url])
      "#{item[:title]} | #{url}\n"
    end
  end
end; end; end
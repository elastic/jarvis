module Jarvis; module Github; module ReviewSearch
  def self.execute
    search_base = "assignee:\"elasticsearch-bot\" state:open"
    
    searches = [
      "org:logstash-plugins",
      "org:elastic"
    ].map {|scope| search_base + " " + scope}

    results = searches.map {|q| ::Jarvis::Github.client.search_issues(q) }

    total = results.reduce(0) {|acc,r| acc + r[:total_count] }
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
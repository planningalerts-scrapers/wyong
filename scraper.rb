require 'scraperwiki'
require 'mechanize'

# Scraping from Masterview 2.0

def scrape_page(page, comment_url)
  page.at("table table").search("tr.tableLine").each do |tr|
    tds = tr.search('td').map{|t| t.inner_html.gsub("\r\n", "").strip}
    day, month, year = tds[2].split("/").map{|s| s.to_i}
    record = {
      "info_url" => (page.uri + tr.at('td').at('a')["href"]).to_s,
      "council_reference" => tds[1].squeeze(" ").strip,
      "date_received" => Date.new(year, month, day).to_s,
      "description" => tds[3].gsub("&amp;", "&").split("<br>")[1].squeeze(" ").strip,
      "address" => tds[3].gsub("&amp;", "&").split("<br>")[0].gsub("\r", " ").gsub("<strong>","").gsub("</strong>","").squeeze(" ").strip,
      "date_scraped" => Date.today.to_s,
      "comment_url" => comment_url
    }

    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      puts "Saving record " + record['council_reference'] + " - " + record['address']
#       puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end

  end
end

# Implement a click on a link that understands stupid asp.net doPostBack
def click(page, doc)
  js = doc["href"] || doc["onclick"]
  if js =~ /javascript:__doPostBack\('(.*)','(.*)'\)/
    event_target = $1
    event_argument = $2
    form = page.form_with(id: "aspnetForm")
    form["__EVENTTARGET"] = event_target
    form["__EVENTARGUMENT"] = event_argument
    form.submit
  elsif js =~ /return false;__doPostBack\('(.*)','(.*)'\)/
    nil
  else
    # TODO Just follow the link likes it's a normal link
    raise
  end
end

url = "http://wsconline.wyong.nsw.gov.au/applicationtracking/modules/applicationmaster/default.aspx?page=found&1=thismonth&4a=437&5=T"
comment_url = "mailto:wsc@wyong.nsw.gov.au"

agent = Mechanize.new

# Read in a page
page = agent.get(url)

# This is weird. There are two forms with the Agree / Disagree buttons. One of them
# works the other one doesn't. Go figure.
form = page.forms.first
button = form.button_with(value: "I Agree")
raise "Can't find agree button" if button.nil?
form.submit(button)
# Doesn't redirect
page = agent.get(url)

scrape_page(page, comment_url)

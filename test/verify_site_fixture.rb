# frozen_string_literal: true

require "json"
require "nokogiri"

root = File.expand_path(ARGV.fetch(0))
manifest = JSON.parse(File.read(File.join(root, "manifest.json")))
site = File.join(root, "site")
read_page = ->(url) { File.read(File.join(site, url.delete_prefix("/"), "index.html")) }
ordinary = manifest.fetch("ordinary_url")
ai = manifest.fetch("ai_url")
html = manifest.fetch("html_url")
home = read_page.call("/")
category = read_page.call("/categories/tech/")
overview = Nokogiri::HTML(read_page.call("/categories/"))
overview.css('.category-group').each do |group|
  count = group.at_css('.category-group-header > span').text.to_i
  expected_preview = [count, 3].min
  raise "分类预览数量错误" unless group.css('.category-posts li').size == expected_preview
  link = group.at_css('.category-title-link')['href']
  raise "分类路径文字与链接不一致" unless group.at_css('.category-command').text.strip == link
  more = group.at_css('.category-more')
  raise "分类省略入口错误" unless (count > 3 ? more && more['href'] == link && more.text == '...' : more.nil?)
end
home_document = Nokogiri::HTML(home)
commands = home_document.css('.terminal-line').map(&:text).map(&:strip)
raise "终端命令格式不统一" unless commands.size == 2 && commands.all? { |command| command.start_with?('fengqing@github:~$ ') }
raise "分类详情路径文字错误" unless Nokogiri::HTML(category).at_css('.eyebrow').text.strip == '/categories/tech/'
feed = File.read(File.join(site, "feed.xml"))
raise "普通文章未出现在首页／分类" unless home.include?(ordinary) && category.include?(ordinary)
[home, category].each do |content|
  raise "AI 或 HTML 泄漏到普通入口" if content.include?(ai) || content.include?(html)
end
# Ordinary feed entries legitimately contain links to referenced AI/HTML in
# their article body. Only AI/HTML becoming independent entries is forbidden.
feed_document = Nokogiri::XML(feed) { |config| config.nonet }
entry_urls = feed_document.xpath('//atom:entry/atom:id | //atom:entry/atom:link/@href', 'atom' => 'http://www.w3.org/2005/Atom').map(&:text)
# Feed plugins may cap recent entries; the intentionally old fixture can fall
# outside that cap as real posts accumulate. Require ordinary entries, not the
# presence of this particular 2000-dated fixture.
raise "普通文章未出现在订阅条目" unless entry_urls.any? { |url| url.match?(%r{\Ahttps?://[^/]+/posts/}) }
raise "AI 或 HTML 被列为独立订阅条目" if entry_urls.any? { |url| url.end_with?(ai) || url.end_with?(html) }
raise "AI 首页缺少文章" unless read_page.call("/ai/").include?(ai)
raise "AI 首页错误选中了主题" unless Nokogiri::HTML(read_page.call("/ai/")).at_css("h1").text.strip == "AI 文"
raise "AI 主题分类缺少文章" unless read_page.call("/ai/categories/tech/").include?(ai)
ai_page = read_page.call(ai)
raise "AI 主题标签链接错误" unless ai_page.include?('/ai/categories/tech/')
raise "AI 被加入全文搜索" unless ai_page.match?(/<main[^>]+data-pagefind-ignore="all"/)
raise "AI 正文缺失" unless ai_page.include?("AI fixture content")
html_page = read_page.call(html)
raise "HTML 查看页缺少加载按钮" unless html_page.include?("data-html-load")
raise "HTML 附件已直接执行" if html_page.include?('id="counter"')
raise "HTML 被加入全文搜索" unless html_page.match?(/<main[^>]+data-pagefind-ignore="all"/)
payload = JSON.parse(File.read(File.join(site, manifest.fetch("payload"))))
raise "HTML 数据包损坏" unless payload["html"].include?('id="counter"') && payload["version"] == 1
raise "旧文章数量异常" unless manifest.fetch("existing_posts").size >= 5
puts "PASS: rendered ordinary/AI/category/feed/search boundaries and isolated HTML data payload."

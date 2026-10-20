# frozen_string_literal: true

require "tmpdir"
require_relative "../scripts/publish-post"
require_relative "../scripts/generate-category-pages"

target = File.expand_path(ARGV.fetch(0))
raise "测试目录已存在，拒绝覆盖：#{target}" if File.exist?(target)
repo = File.expand_path("..", __dir__)
source = File.join(target, "source")
FileUtils.mkdir_p(source)
%w[_config.yml _layouts _includes _data _posts assets index.html categories.html ai.html about.md copyright.md].each do |entry|
  path = File.join(repo, entry)
  FileUtils.cp_r(path, File.join(source, entry)) if File.exist?(path)
end
config = YAML.safe_load(File.read(File.join(source, "_config.yml")))
config.delete("analytics")
File.write(File.join(source, "_config.yml"), YAML.dump(config))
manifest = nil
Dir.mktmpdir("blog-integration-input-") do |vault|
  File.write(File.join(vault, "2000-01-01-main.md"), "---\ntitle: Integration ordinary\ncategories: [tech]\n---\n## Body\n[[analysis]]\n[Interactive HTML](demo.html)\n")
  File.write(File.join(vault, "analysis.md"), "---\ntitle: Integration AI\ndate: 2000-01-01\ncategories: [ai, tech]\n---\n## Analysis\nAI fixture content\n")
  File.write(File.join(vault, "demo.html"), '<!doctype html><html><body><button id="counter">0</button><script>document.querySelector("#counter").onclick = () => { document.querySelector("#counter").textContent = "1"; };</script></body></html>')
  publisher = PostPublisher.new(source: File.join(vault, "2000-01-01-main.md"), repo: source, slug: "integration-ordinary", compress_images: false)
  result = publisher.plan
  publisher.write
  manifest = { ordinary_url: result[:url], ai_url: result[:references].first[:url], html_url: result[:html_documents].first[:url],
               payload: result[:html_documents].first[:payload_destination], existing_posts: Dir[File.join(repo, "_posts", "*.md")].map { |path| File.basename(path) } }
end
generate_category_pages(source)
File.write(File.join(target, "manifest.json"), JSON.pretty_generate(manifest))
puts "Prepared isolated fixture at #{target}; no fixture content will be deployed."

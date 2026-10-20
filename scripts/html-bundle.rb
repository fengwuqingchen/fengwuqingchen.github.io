# frozen_string_literal: true

require "base64"
require "uri"

# Compile trusted-author documents to data, never to executable same-origin HTML.
# Nokogiri parses markup only; no source script is executed while publishing.
class HtmlBundle
  MIME = { ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".gif" => "image/gif",
           ".webp" => "image/webp", ".avif" => "image/avif", ".svg" => "image/svg+xml",
           ".ico" => "image/x-icon", ".woff" => "font/woff", ".woff2" => "font/woff2", ".ttf" => "font/ttf" }.freeze
  attr_reader :dependencies

  def initialize(limit:, total_limit:, image_limit:, compress_images:)
    require "nokogiri"
    @limit, @total_limit, @image_limit = limit, total_limit, image_limit
    @compress_images = compress_images
    @dependencies = {}
  rescue LoadError
    raise "HTML 上传需要 Nokogiri；请运行 gem install nokogiri"
  end

  def read(path)
    path = File.realpath(path)
    unless @dependencies.key?(path)
      size = File.size(path)
      limit = MIME.fetch(File.extname(path).downcase, "").start_with?("image/") ? @image_limit : @limit
      raise "HTML 资源过大：#{path}" if size > limit
      @dependencies[path] = { source: path, size: size }
      raise "HTML 资源合计超限" if @dependencies.values.sum { |item| item[:size] } > @total_limit
    end
    File.binread(path)
  end

  def local_path(target, base)
    decoded = CGI.unescapeHTML(target.to_s.strip)
    raise "HTML 外部资源暂不允许，请将其下载到本地后引用：#{decoded}" if decoded.match?(%r{\A(?:[a-z][\w+.-]*:|//)}i)
    raw = URI::DEFAULT_PARSER.unescape(decoded.split(/[?#]/, 2).first.to_s)
    raise "HTML 资源必须为明确的本地相对路径：#{decoded}" if raw.empty? || raw.start_with?("/")
    path = File.expand_path(raw, File.dirname(base))
    raise "找不到 HTML 资源：#{path}" unless File.file?(path)
    File.realpath(path)
  end

  def data_url(target, base)
    return target if target.start_with?("#")
    if target.start_with?("data:")
      raise "HTML 不支持这种 data 资源" unless target.match?(%r{\Adata:(?:image/|font/)}i)
      return target
    end
    path = local_path(target, base)
    ext = File.extname(path).downcase
    mime = MIME[ext]
    raise "HTML 资源类型不受支持：#{path}" unless mime
    bytes = read(path)
    if mime.start_with?("image/")
      optimized = ImageOptimizer.optimize(path, enabled: @compress_images)
      bytes = optimized[:bytes]
      mime = MIME.fetch(optimized[:extension], mime)
    end
    "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"
  end

  def css(text, base)
    raise "暂不支持 CSS @import；请将样式合并到本地 CSS：#{base}" if text.match?(/@import\b/i)
    text.gsub(/url\(\s*(?:"([^"]*)"|'([^']*)'|([^)'"\s]+))\s*\)/i) do
      target = Regexp.last_match(1) || Regexp.last_match(2) || Regexp.last_match(3)
      "url(\"#{data_url(target, base)}\")"
    end
  end

  def compile(path)
    raw = read(path).force_encoding("UTF-8")
    raise "HTML 文件必须为 UTF-8：#{path}" unless raw.valid_encoding?
    doc = Nokogiri::HTML(raw, nil, "UTF-8") { |config| config.nonet }
    # Policy belongs to the viewer, not to a document supplied by the author.
    doc.css("base, meta[http-equiv], iframe, frame, frameset, object, embed, portal").remove
    doc.css("script").each do |node|
      raise "暂不支持 ES module；请将 HTML 打包成自包含的普通脚本" if node["type"].to_s.downcase == "module"
      next unless node["src"]
      script_path = local_path(node["src"], path)
      raise "HTML 脚本必须为本地 .js 文件" unless File.extname(script_path).downcase == ".js"
      code = read(script_path).force_encoding("UTF-8")
      raise "本地脚本必须为 UTF-8" unless code.valid_encoding?
      raise "脚本包含结束标签，请先打包处理：#{script_path}" if code.match?(%r{</script}i)
      node.remove_attribute("src")
      node.remove_attribute("integrity")
      node.content = code
    end
    doc.css("link").each do |node|
      if node["rel"].to_s.downcase == "stylesheet"
        css_path = local_path(node["href"], path)
        raise "样式必须为本地 .css 文件" unless File.extname(css_path).downcase == ".css"
        style = Nokogiri::XML::Node.new("style", doc)
        style.content = css(read(css_path).force_encoding("UTF-8"), css_path)
        node.replace(style)
      else
        node.remove
      end
    end
    doc.css("style").each { |node| node.content = css(node.content, path) }
    doc.css("[style]").each { |node| node["style"] = css(node["style"], path) }
    doc.css("[srcset]").each { |node| raise "HTML srcset 暂不支持，请改用单一 src：#{node.name}" }
    doc.css("[src], [poster], image").each do |node|
      %w[src poster href xlink:href].each do |attribute|
        next unless node[attribute]
        raise "HTML 不支持媒体资源：#{node.name}" unless %w[img image input].include?(node.name)
        node[attribute] = data_url(node[attribute], path)
      end
    end
    # Navigation and forms aren't needed for local interactive demonstrations.
    doc.css("a[href], area[href]").each do |node|
      node["href"] = "#" unless node["href"].start_with?("#")
      %w[target ping download].each { |attribute| node.remove_attribute(attribute) }
    end
    doc.css("form").each { |node| node.remove_attribute("action"); node.remove_attribute("target") }
    doc.to_html
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "cgi"
require "digest"
require "fileutils"
require "find"
require "json"
require "optparse"
require "uri"
require "yaml"
require_relative "image-optimizer"
require_relative "html-bundle"

# Import a Markdown article and its local resources without changing the source.
class PostPublisher
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .avif .svg .bmp .ico].freeze
  BLOCKED_EXTENSIONS = %w[.html .htm .js .mjs .exe .sh .rb .py .php].freeze
  MIB = 1024 * 1024

  def initialize(source:, repo:, slug: nil, vault: nil, date: nil,
                 image_mb: 10, attachment_mb: 20, total_mb: 100, compress_images: true)
    @source = File.realpath(source)
    @root_source = @source
    @repo = File.realpath(repo)
    @vault = vault && File.realpath(vault)
    @slug = slug
    @date = date
    @compress_images = compress_images
    @requested_slug = slug
    @limits = [image_mb, attachment_mb, total_mb].map { |value| Float(value) * MIB }
    raise "大小限制必须大于零" unless @limits.all?(&:positive?)
    @resources = {}
    @references = {}
    @note_sizes = {}
    @stack = []
    @resource_bytes = {}
    @html_documents = {}
  end

  def plan
    metadata, raw_body = read_document(@source)
    title = metadata.fetch("title")
    ai = metadata["ai_generated"] == true
    reference_only = metadata["reference_only"] == true && !ai
    check_note_size(@source) if ai || reference_only
    filename = File.basename(@source, File.extname(@source))
    filename_date = filename[/\A\d{4}-\d{1,2}-\d{1,2}/]
    article_date = Date.parse(@date || filename_date || metadata["date"]&.to_s || Date.today.iso8601)
    raise "发布日期不能在未来" if article_date > Date.today
    @slug ||= filename.sub(/\A\d{4}-\d{1,2}-\d{1,2}-/, "").gsub(/\s+/, "-")
    raise "slug 只能包含文字、数字、下划线与短横线" if !ai && !@slug.match?(/\A[\p{L}\p{N}_-]+\z/u)
    @post_path = "_posts/#{article_date.iso8601}-#{@slug}.md"
    raise "目标文章已存在：#{@post_path}；请直接编辑仓库中的文章" if !ai && !reference_only && File.exist?(File.join(@repo, @post_path))

    @stack << @source
    body = rewrite_body(raw_body)
    @stack.pop
    metadata["render_with_liquid"] = false
    url = "/posts/#{@slug}/"
    if ai
      metadata["date"] = article_date.iso8601 if @date
      metadata["slug"] ||= @requested_slug if @requested_slug
      note = build_reference(metadata, body, @source)
      @post_path, @article, url = note.values_at(:destination, :content, :url)
      @references.delete(@post_path)
    elsif reference_only
      metadata["date"] = article_date.iso8601
      metadata.merge!("reference_only" => true, "search_exclude" => true, "layout" => "post", "published" => true)
      @post_path = "_references/#{@slug}.md"
      url = metadata["permalink"] = "/references/#{@slug}/"
      raise "目标文章已存在：#{@post_path}" if File.exist?(File.join(@repo, @post_path))
      @article = "#{YAML.dump(metadata)}---\n\n#{body}"
    else
      metadata["date"] = article_date.iso8601
      @article = "#{YAML.dump(metadata)}---\n\n#{body}"
    end
    total = @resources.values.sum { |resource| resource[:size] } + @note_sizes.values.sum + @html_documents.values.sum { |item| item[:payload].bytesize }
    raise "资源合计 #{format_size(total)}，超过总限制 #{format_size(@limits[2])}" if total > @limits[2]
    { post: @post_path, kind: ai ? "ai" : reference_only ? "reference" : "post",
      references: @references.values.map { |note| note.reject { |key, _| key == :content } },
      html_documents: @html_documents.values.map { |item| item.reject { |key, _| [:payload, :content].include?(key) } },
      resources: @resources.values, total_bytes: total, url: url, title: title }
  end

  def write
    raise "请先完成 plan 校验" unless @article
    @resources.each_value do |resource|
      destination = File.join(@repo, resource[:destination])
      FileUtils.mkdir_p(File.dirname(destination))
      if @resource_bytes.key?(resource[:source])
        File.binwrite(destination, @resource_bytes.fetch(resource[:source]))
      else
        FileUtils.cp(resource[:source], destination)
      end
    end
    @html_documents.each_value do |item|
      write_note(item[:destination], item[:content])
      write_note(item[:payload_destination], item[:payload])
    end
    @references.each_value { |note| write_note(note[:destination], note[:content]) }
    write_note(@post_path, @article)
  end

  private

  def read_document(path)
    source = File.read(path, encoding: "UTF-8")
    match = source.match(/\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)/m)
    metadata = match ? YAML.safe_load(match[1], permitted_classes: [Date, Time]) : { "ai_generated" => true }
    raise "YAML 必须是字段映射：#{path}" unless metadata.is_a?(Hash)
    metadata["title"] ||= File.basename(path, File.extname(path))
    raise "title 不能为空：#{path}" unless metadata["title"].is_a?(String) && !metadata["title"].strip.empty?
    categories, tags = Array(metadata["categories"]), Array(metadata["tags"])
    marked = (categories + tags).any? { |value| value.to_s.downcase == "ai" }
    raise "AI 分类／标签与 ai_generated: false 冲突：#{path}" if marked && metadata["ai_generated"] == false
    ai = !match || marked || metadata["ai_generated"] == true
    metadata["ai_generated"] = ai
    metadata["categories"] = categories.reject { |value| value.to_s.downcase == "ai" }
    metadata["tags"] = tags
    catalog = YAML.safe_load(File.read(File.join(@repo, "_data/categories.yml")))
    unknown = metadata["categories"] - catalog.map { |category| category.fetch("slug") }
    raise "分类未注册：#{unknown.join(', ')}" unless unknown.empty?
    raise "普通文章分类不能为空：#{path}" if @stack.empty? && !ai && metadata["reference_only"] != true && metadata["categories"].empty?
    filename_date = File.basename(path)[/\A\d{4}-\d{1,2}-\d{1,2}/]
    metadata["date"] = Date.parse((path == @root_source && @date) || metadata["date"]&.to_s || filename_date || File.mtime(path).strftime("%Y-%m-%d")).iso8601
    raise "发布日期不能在未来：#{path}" if Date.parse(metadata["date"]) > Date.today
    [metadata, match ? source[match.end(0)..] : source]
  end

  def check_note_size(path)
    size = File.size(path)
    raise "引用文章过大：#{path}" if size > @limits[1]
    @note_sizes[path] = size
  end

  def build_reference(metadata, body, path)
    ai = metadata["ai_generated"] == true
    metadata = metadata.merge("layout" => "post", "reference_only" => !ai, "search_exclude" => true,
                              "render_with_liquid" => false, "published" => true)
    metadata.delete("permalink")
    # Canonical metadata and stable AI resource paths give the same default URL
    # whether a document is published alone or reached through a reference.
    digest = Digest::SHA256.hexdigest(JSON.generate(metadata.sort.to_h) + body)
    identifier = ai && metadata["slug"] ? metadata["slug"] : digest
    raise "AI slug 只能包含文字、数字、下划线与短横线" unless identifier.is_a?(String) && identifier.match?(/\A[\p{L}\p{N}_-]+\z/u)
    url = ai ? "/ai/posts/#{identifier}/" : "/references/#{identifier}/"
    destination = "#{ai ? '_ai_articles' : '_references'}/#{identifier}.md"
    metadata["permalink"] = url
    content = "#{YAML.dump(metadata)}---\n\n#{body}"
    existing = File.join(@repo, destination)
    if File.exist?(existing)
      # Do not silently overwrite an explicit slug with different content.
      existing_text = File.read(existing)
      existing_match = existing_text.match(/\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)/m)
      existing_metadata = existing_match && YAML.safe_load(existing_match[1], permitted_classes: [Date, Time])
      existing_body = existing_match && existing_text[existing_match.end(0)..].sub(/\A\n/, "")
      raise "引用文章目标冲突：#{destination}；请直接编辑仓库文件或使用新 slug" unless existing_metadata == metadata && existing_body == body
    end
    note = { source: path, destination: destination, url: url, kind: ai ? "ai" : "reference", content: content }
    @references[destination] = note
    note
  end

  def write_note(path, content)
    destination = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, content)
  end

  def reference_url(path)
    raise "引用嵌套不能超过两层：#{path}" if @stack.length > 2
    raise "循环引用：#{(@stack + [path]).join(' → ')}" if @stack.include?(path)
    check_note_size(path)
    metadata, raw_body = read_document(path)
    previous_source = @source
    @source = path
    @stack << path
    begin
      body = rewrite_body(raw_body)
    ensure
      @stack.pop
      @source = previous_source
    end
    build_reference(metadata, body, path).fetch(:url)
  end

  def html_url(path)
    return @html_documents.fetch(path).fetch(:url) if @html_documents.key?(path)
    bundle = HtmlBundle.new(limit: @limits[1], total_limit: @limits[2], image_limit: @limits[0], compress_images: @compress_images)
    html = bundle.compile(path)
    payload = JSON.generate({ version: 1, html: html })
    digest = Digest::SHA256.hexdigest(payload)
    url = "/html/#{digest}/"
    payload_destination = "assets/html-data/#{digest}.json"
    metadata = { "layout" => "html-reference", "title" => File.basename(path), "search_exclude" => true,
                 "reference_only" => true, "permalink" => url, "html_payload" => "/#{payload_destination}" }
    @html_documents[path] = { source: path, url: url, destination: "_html_documents/#{digest}.html",
                              payload_destination: payload_destination, dependencies: bundle.dependencies.values,
                              payload: payload, content: "#{YAML.dump(metadata)}---\n" }
    url
  end

  def format_size(bytes)
    format("%.2f MB", bytes.to_f / MIB)
  end

  def rewrite_body(body)
    fence = nil
    body.lines.map do |line|
      if (marker = line.match(/^\s{0,3}(`{3,}|~{3,})/))
        if fence.nil?
          fence = marker[1]
        elsif marker[1][0] == fence[0] && marker[1].size >= fence.size
          fence = nil
        end
        next line
      end
      next line if fence || line.match?(/^(?: {4}|\t)/)
      # Keep inline code examples intact too.
      line.split(/(`+[^`]*`+)/).map.with_index do |part, index|
        index.odd? ? part : rewrite_links(part)
      end.join
    end.join
  end

  def rewrite_links(text)
    text = text.gsub(/(!?)\[\[([^\]\n]+)\]\]/) do
      embedded, reference = Regexp.last_match(1), Regexp.last_match(2)
      target, label = reference.split("|", 2)
      path, fragment = target.split("#", 2)
      extension = File.extname(path).downcase
      target = "#{path}.md#{fragment ? '#' + fragment : ''}" if extension.empty?
      url = local_url(target)
      image = embedded == "!" && IMAGE_EXTENSIONS.include?(extension)
      dimensions = label&.match(/\A([1-9]\d*)(?:x([1-9]\d*))?\z/)
      if image && dimensions
        # HTML dimensions survive kramdown; CSS keeps images responsive.
        attributes = "width=\"#{dimensions[1]}\""
        attributes += " height=\"#{dimensions[2]}\"" if dimensions[2]
        next "<img src=\"#{CGI.escapeHTML(url)}\" alt=\"#{CGI.escapeHTML(File.basename(path))}\" #{attributes}>"
      end
      label = File.basename(path) if label.nil? || label.match?(/\A\d+(?:x\d+)?\z/)
      label = label.gsub(/[\[\]]/, "")
      "#{image ? '!' : ''}[#{label}](#{url})"
    end
    # Inline Markdown links: scan balanced parentheses so filenames can contain them.
    cursor = 0
    output = +""
    while (match = /!?\[[^\]\n]*\]\(/.match(text, cursor))
      output << text[cursor...match.end(0)]
      start = match.end(0)
      position = start
      depth = 1
      while position < text.length && depth.positive?
        character = text[position]
        if character == "\\"
          position += 2
          next
        end
        depth += 1 if character == "("
        depth -= 1 if character == ")"
        position += 1
      end
      raise "Markdown 链接括号未闭合" unless depth.zero?
      destination = text[start...(position - 1)]
      output << rewrite_destination(destination) << ")"
      cursor = position
    end
    text = output << text[cursor..]
    text = text.gsub(/^(\s{0,3}\[[^\]]+\]:\s*)(.+)$/) { "#{Regexp.last_match(1)}#{rewrite_destination(Regexp.last_match(2))}" }
    text.gsub(/((?:src|href)\s*=\s*)(["'])(.*?)\2/i) do
      prefix, quote, target = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
      "#{prefix}#{quote}#{local_url(target)}#{quote}"
    end
  end

  def rewrite_destination(destination)
    match = destination.match(/\A\s*(?:<([^>]+)>|(.*?))((?:\s+["'].*)?\s*)\z/m)
    target = match[1] || match[2]
    rewritten = local_url(target)
    "#{rewritten}#{match[3]}"
  end

  def local_url(target)
    return target if target.empty? || target.start_with?("#", "//") || target.match?(/\A(?:https?|mailto|tel|data):/i)
    return target if @resources.values.any? { |resource| target.split(/[?#]/, 2).first == "/#{resource[:destination]}" }
    return target if @references.values.any? { |note| target.split(/[?#]/, 2).first == note[:url] }
    return target if @html_documents.values.any? { |item| target.split(/[?#]/, 2).first == item[:url] }
    raise "不支持的本地资源协议：#{target}" if target.match?(/\A\w+:/) && !target.start_with?("file:")
    raw_path, suffix = target.split(/(?=[?#])/, 2)
    raw_path = raw_path.sub(/\Afile:\/\//, "")
    raw_path = URI::DEFAULT_PARSER.unescape(raw_path).gsub(/\\([ ()])/, '\1')
    path = resolve_resource(raw_path)
    return "#{reference_url(path)}#{suffix}" if File.extname(path).downcase == ".md"
    return "#{html_url(path)}#{suffix}" if %w[.html .htm].include?(File.extname(path).downcase)
    unless @resources.key?(path)
      extension = File.extname(path).downcase
      raise "不发布可执行或网页附件：#{path}" if BLOCKED_EXTENSIONS.include?(extension)
      size = File.size(path)
      limit = @limits[IMAGE_EXTENSIONS.include?(extension) ? 0 : 1]
      raise "资源过大：#{path}（#{format_size(size)} > #{format_size(limit)}）" if size > limit
      optimized = IMAGE_EXTENSIONS.include?(extension) ? ImageOptimizer.optimize(path, enabled: @compress_images) : nil
      bytes = optimized ? optimized[:bytes] : File.binread(path)
      digest = Digest::SHA256.hexdigest(bytes)
      @resource_bytes[path] = bytes if optimized && optimized[:compression] == "lossless-webp"
      @resources[path] = { source: path, size: size,
                           original_size: size, compression: optimized ? optimized[:compression] : "not-image",
                           destination: "assets/posts/media/#{digest}#{optimized ? optimized[:extension] : extension}" }
      @resources[path][:size] = bytes.bytesize
    end
    "/#{@resources.fetch(path)[:destination]}#{suffix}"
  end

  def resolve_resource(raw_path)
    candidates = [File.expand_path(raw_path, File.dirname(@source)),
                  File.expand_path(raw_path, File.join(File.dirname(@source), "attachments"))]
    candidates << File.expand_path(raw_path, @vault) if @vault
    existing = candidates.select { |path| File.file?(path) }.map { |path| File.realpath(path) }.uniq
    if existing.empty?
      root = @vault || File.dirname(@source)
      Find.find(root) do |path|
        if File.directory?(path) && %w[.git .obsidian node_modules].include?(File.basename(path))
          Find.prune
        elsif File.file?(path) && File.basename(path) == File.basename(raw_path)
          existing << File.realpath(path)
        end
      end
    end
    existing.uniq!
    raise "找不到资源：#{raw_path}" if existing.empty?
    raise "同名资源不唯一，请使用明确的相对路径：#{raw_path}" if existing.size > 1
    existing.first
  end
end

if $PROGRAM_NAME == __FILE__
  options = { repo: File.expand_path("..", __dir__) }
  dry_run = false
  publish = false
  parser = OptionParser.new do |opts|
    opts.banner = '用法：ruby scripts/publish-post.rb "文章.md" [选项]'
    opts.on("--slug SLUG", "文章 URL 名称") { |value| options[:slug] = value }
    opts.on("--vault PATH", "在此 Obsidian 库内查找附件") { |value| options[:vault] = value }
    opts.on("--date DATE", "发布日期 YYYY-MM-DD") { |value| options[:date] = value }
    opts.on("--image-mb NUMBER", Float, "单张图片上限，默认 10 MB") { |value| options[:image_mb] = value }
    opts.on("--attachment-mb NUMBER", Float, "单个附件上限，默认 20 MB") { |value| options[:attachment_mb] = value }
    opts.on("--total-mb NUMBER", Float, "资源总上限，默认 100 MB") { |value| options[:total_mb] = value }
    opts.on("--no-compress-images", "关闭图片无损优化，上传原图") { options[:compress_images] = false }
    opts.on("--dry-run", "只检验并输出清单，不写文件") { dry_run = true }
    opts.on("--publish", "导入后提交并推送 main，触发 GitHub Pages") { publish = true }
    opts.on("-h", "--help") { puts opts; exit }
  end
  begin
    parser.parse!
    raise parser.banner unless ARGV.size == 1
    options[:source] = ARGV.first
    if publish && !dry_run
      Dir.chdir(options[:repo]) do
        raise "必须在 main 分支发布" unless `git branch --show-current`.strip == "main"
        raise "仓库有未提交改动；请先提交或保存，避免混入发布" unless `git status --porcelain`.strip.empty?
        raise "无法同步远端，请检查网络；没有生成文章" unless system("git", "pull", "--ff-only", "origin", "main")
      end
    end
    publisher = PostPublisher.new(**options)
    result = publisher.plan
    puts JSON.pretty_generate(result)
    unless dry_run
      publisher.write
      if publish
        Dir.chdir(options[:repo]) do
          paths = [result[:post]] + (result[:resources] + result[:references]).map { |resource| resource[:destination] }
          paths += result[:html_documents].flat_map { |item| [item[:destination], item[:payload_destination]] }
          raise "Git 暂存失败" unless system("git", "add", "--", *paths)
          raise "Git 提交失败" unless system("git", "commit", "-m", "post: #{result[:title]}")
          raise "推送失败；文件与提交已保留，请重试 git push origin main" unless system("git", "push", "origin", "main")
        end
      end
    end
  rescue StandardError => error
    warn "发布失败：#{error.message}"
    exit 1
  end
end

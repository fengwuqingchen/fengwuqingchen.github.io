#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "find"
require "json"
require "optparse"
require "uri"
require "yaml"

# Import a Markdown article and its local resources without changing the source.
class PostPublisher
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .avif .svg .bmp .ico].freeze
  BLOCKED_EXTENSIONS = %w[.html .htm .js .mjs .exe .sh .rb .py .php].freeze
  MIB = 1024 * 1024

  def initialize(source:, repo:, slug: nil, vault: nil, date: nil,
                 image_mb: 10, attachment_mb: 20, total_mb: 100)
    @source = File.realpath(source)
    @repo = File.realpath(repo)
    @vault = vault && File.realpath(vault)
    @slug = slug
    @date = date
    @limits = [image_mb, attachment_mb, total_mb].map { |value| Float(value) * MIB }
    raise "大小限制必须大于零" unless @limits.all?(&:positive?)
    @resources = {}
  end

  def plan
    source_text = File.read(@source, encoding: "UTF-8")
    match = source_text.match(/\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)/m)
    raise "文章必须包含 YAML front matter（title、categories、tags）" unless match
    metadata = YAML.safe_load(match[1], permitted_classes: [Date, Time])
    raise "YAML 必须是字段映射" unless metadata.is_a?(Hash)
    title = metadata["title"]
    raise "title 不能为空" unless title.is_a?(String) && !title.strip.empty?
    categories = Array(metadata["categories"])
    catalog = YAML.safe_load(File.read(File.join(@repo, "_data/categories.yml")))
    unknown = categories - catalog.map { |category| category.fetch("slug") }
    raise "分类不能为空或未注册：#{unknown.join(', ')}" if categories.empty? || !unknown.empty?
    metadata["categories"] = categories
    metadata["tags"] = Array(metadata["tags"])

    filename = File.basename(@source, File.extname(@source))
    filename_date = filename[/\A\d{4}-\d{1,2}-\d{1,2}/]
    article_date = Date.parse(@date || filename_date || metadata["date"].to_s)
    raise "发布日期不能在未来" if article_date > Date.today
    @slug ||= filename.sub(/\A\d{4}-\d{1,2}-\d{1,2}-/, "").gsub(/\s+/, "-")
    raise "slug 只能包含文字、数字、下划线与短横线" unless @slug.match?(/\A[\p{L}\p{N}_-]+\z/u)
    @asset_prefix = "assets/posts/#{article_date.iso8601}-#{@slug}"
    @post_path = "_posts/#{article_date.iso8601}-#{@slug}.md"
    raise "目标文章已存在：#{@post_path}；请直接编辑仓库中的文章" if File.exist?(File.join(@repo, @post_path))

    body = rewrite_body(source_text[match.end(0)..])
    total = @resources.values.sum { |resource| resource[:size] }
    raise "资源合计 #{format_size(total)}，超过总限制 #{format_size(@limits[2])}" if total > @limits[2]
    metadata["date"] = article_date.iso8601
    metadata["render_with_liquid"] = false
    @article = "#{YAML.dump(metadata)}---\n\n#{body}"
    { post: @post_path, resources: @resources.values, total_bytes: total,
      url: "/posts/#{@slug}/", title: title }
  end

  def write
    raise "请先完成 plan 校验" unless @article
    @resources.each_value do |resource|
      destination = File.join(@repo, resource[:destination])
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(resource[:source], destination)
    end
    File.write(File.join(@repo, @post_path), @article)
  end

  private

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
      raise "暂不支持发布 Obsidian 笔记链接/嵌入：#{target}，请改为公开 URL" if extension.empty? || extension == ".md"
      url = local_url(target)
      image = embedded == "!" && IMAGE_EXTENSIONS.include?(extension)
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
    raise "不支持的本地资源协议：#{target}" if target.match?(/\A\w+:/) && !target.start_with?("file:")
    raw_path, suffix = target.split(/(?=[?#])/, 2)
    raw_path = raw_path.sub(/\Afile:\/\//, "")
    raw_path = URI::DEFAULT_PARSER.unescape(raw_path).gsub(/\\([ ()])/, '\1')
    path = resolve_resource(raw_path)
    unless @resources.key?(path)
      extension = File.extname(path).downcase
      raise "不发布可执行或网页附件：#{path}" if BLOCKED_EXTENSIONS.include?(extension)
      size = File.size(path)
      limit = @limits[IMAGE_EXTENSIONS.include?(extension) ? 0 : 1]
      raise "资源过大：#{path}（#{format_size(size)} > #{format_size(limit)}）" if size > limit
      digest = Digest::SHA256.file(path).hexdigest
      @resources[path] = { source: path, size: size,
                           destination: "#{@asset_prefix}/#{digest}#{extension}" }
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
          paths = [result[:post]] + result[:resources].map { |resource| resource[:destination] }
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

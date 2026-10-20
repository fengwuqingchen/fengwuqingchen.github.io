# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../scripts/publish-post"

class PublishPostTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("blog-publish-test-")
    @repo = File.join(@root, "repo")
    @source_dir = File.join(@root, "vault")
    FileUtils.mkdir_p([File.join(@repo, "_posts"), File.join(@repo, "_data"), File.join(@source_dir, "attachments")])
    File.write(File.join(@repo, "_data/categories.yml"), "- slug: tech\n  name: 技术\n")
    @source = File.join(@source_dir, "2026-1-2-测试.md")
    @png = File.join(@source_dir, "attachments", "my image.png")
    File.binwrite(@png, "image-test-bytes")
    File.binwrite(File.join(@source_dir, "report (1).pdf"), "pdf-test-bytes")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write_source(body)
    File.write(@source, "---\ntitle: 测试\ncategories: tech\ntags: 技术\n---\n#{body}")
  end

  def publisher(**options)
    PostPublisher.new(source: @source, repo: @repo, slug: "test-post", **options)
  end

  def test_imports_obsidian_images_and_markdown_attachments_preserving_examples_and_external_urls
    body = "![[my image.png|400]]\n[PDF](<report (1).pdf> \"附件\")\n" \
           "![另一处](attachments/my%20image.png)\n[外部](https://example.com)\n" \
           "`![[missing.png]]`\n```md\n![[missing.png]]\n```\n"
    write_source(body)
    importer = publisher
    plan = importer.plan
    assert_equal 2, plan[:resources].size
    assert_equal "_posts/2026-01-02-test-post.md", plan[:post]
    refute File.exist?(File.join(@repo, plan[:post]))
    importer.write
    article = File.read(File.join(@repo, plan[:post]))
    assert_includes article, "render_with_liquid: false"
    assert_match(%r{<img src="/assets/posts/[^"]+" alt="my image.png" width="400">}, article)
    assert_includes article, '[PDF](/assets/posts/'
    assert_includes article, ' "附件")'
    assert_includes article, "https://example.com"
    assert_includes article, "`![[missing.png]]`"
    assert_includes article, "```md\n![[missing.png]]\n```"
    plan[:resources].each do |resource|
      assert_equal File.binread(resource[:source]), File.binread(File.join(@repo, resource[:destination]))
    end
    assert_equal "image-test-bytes", File.binread(@png)
  end

  def test_supports_reference_links_html_images_and_balanced_parentheses
    write_source("[报告](report%20(1).pdf#page=2)\n[附件][pdf]\n[pdf]: <report (1).pdf>\n<img src=\"attachments/my%20image.png\">\n")
    importer = publisher
    result = importer.plan
    importer.write
    article = File.read(File.join(@repo, result[:post]))
    assert_equal 2, result[:resources].size
    assert_includes article, ".pdf#page=2)"
    assert_match(/\[pdf\]: \/assets\/posts\/.+\.pdf/, article)
    assert_match(/<img src="\/assets\/posts\/.+\.png">/, article)
  end

  def test_obsidian_image_dimensions_survive_upload_without_changing_unscaled_images
    write_source("![[my image.png|712]]\n![[my image.png|300x200]]\n![[my image.png]]\n")
    importer = publisher
    result = importer.plan
    importer.write
    article = File.read(File.join(@repo, result[:post]))
    assert_includes article, 'width="712"'
    assert_includes article, 'width="300" height="200"'
    assert_includes article, '![my image.png](/assets/posts/'
    assert_equal 1, result[:resources].size
  end

  def test_oversized_images_fail_before_writing_anything
    write_source("![[my image.png]]")
    error = assert_raises(RuntimeError) { publisher(image_mb: 0.000001).plan }
    assert_includes error.message, "资源过大"
    assert_empty Dir.children(File.join(@repo, "_posts"))
    refute File.exist?(File.join(@repo, "assets"))
  end

  def test_missing_resource_and_total_limit_fail_before_writing
    write_source("![[missing.png]]")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "找不到资源"
    write_source("![[my image.png]]\n[PDF](<report (1).pdf>)")
    assert_includes assert_raises(RuntimeError) { publisher(total_mb: 0.00002).plan }.message, "资源合计"
  end

  def test_attachment_size_limit_and_ambiguous_names
    write_source("[PDF](<report (1).pdf>)")
    assert_includes assert_raises(RuntimeError) { publisher(attachment_mb: 0.000001).plan }.message, "资源过大"
    FileUtils.mkdir_p([File.join(@source_dir, "a"), File.join(@source_dir, "b")])
    %w[a b].each { |dir| File.write(File.join(@source_dir, dir, "same.png"), dir) }
    write_source("![[same.png]]")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "不唯一"
  end

  def test_invalid_category_existing_post_and_active_attachments_are_rejected
    write_source("text")
    File.write(@source, File.read(@source).sub("categories: tech", "categories: missing"))
    assert_raises(RuntimeError) { publisher.plan }
    write_source("[脚本](script.js)")
    File.write(File.join(@source_dir, "script.js"), "demo")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "不发布"
    write_source("text")
    importer = publisher
    importer.plan
    importer.write
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "已存在"
  end

  def test_recursively_publishes_two_reference_levels_and_relative_assets
    FileUtils.mkdir_p(File.join(@source_dir, "notes"))
    File.write(File.join(@source_dir, "notes", "first.md"), "[[second#detail|深入]]\n![图](../attachments/my%20image.png)\n")
    File.write(File.join(@source_dir, "notes", "second.md"), "## detail\n[附件](../report%20(1).pdf)\n")
    write_source("[[notes/first|资料]]\n[重复](notes/first.md)\n![[notes/first.md]]\n")
    importer = publisher
    result = importer.plan
    assert_equal 2, result[:references].size
    assert_equal 2, result[:resources].size
    importer.write
    assert_equal 2, Dir.children(File.join(@repo, "_ai_articles")).size
    root = File.read(File.join(@repo, result[:post]))
    assert_equal 3, root.scan(%r{\(/ai/posts/}).size
    result[:references].each do |note|
      content = File.read(File.join(@repo, note[:destination]))
      assert_includes content, "ai_generated: true"
      assert_includes content, "reference_only: false"
      assert_includes content, "search_exclude: true"
      assert_includes content, "render_with_liquid: false"
    end
    first = result[:references].find { |note| note[:source].end_with?("first.md") }
    assert_includes File.read(File.join(@repo, first[:destination])), "#detail)"
    assert_equal "[[second#detail|深入]]\n![图](../attachments/my%20image.png)\n", File.read(first[:source])
  end

  def test_depth_and_cycles_fail_without_writing
    write_source("[[a]]")
    File.write(File.join(@source_dir, "a.md"), "[[b]]")
    File.write(File.join(@source_dir, "b.md"), "[[c]]")
    File.write(File.join(@source_dir, "c.md"), "third level")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "两层"
    File.write(File.join(@source_dir, "a.md"), "[[a]]")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "循环引用"
    assert_empty Dir.children(File.join(@repo, "_posts"))
    refute File.exist?(File.join(@repo, "_references"))
  end

  def test_shared_reference_is_checked_at_each_depth
    write_source("[[b]]\n[[a]]")
    File.write(File.join(@source_dir, "a.md"), "[[b]]")
    File.write(File.join(@source_dir, "b.md"), "[[c]]")
    File.write(File.join(@source_dir, "c.md"), "leaf")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "两层"
  end

  def test_front_matter_free_root_is_an_ai_reference_not_a_post
    File.write(@source, "# 自动生成\ntext")
    assert_includes assert_raises(RuntimeError) { publisher(attachment_mb: 0.000001).plan }.message, "引用文章过大"
    importer = publisher
    result = importer.plan
    assert_equal "_ai_articles/test-post.md", result[:post]
    assert_equal "/ai/posts/test-post/", result[:url]
    importer.write
    assert_empty Dir.children(File.join(@repo, "_posts"))
    assert_includes File.read(File.join(@repo, result[:post])), "ai_generated: true"
    assert_includes File.read(File.join(@repo, result[:post])), "search_exclude: true"
  end

  def test_yaml_reference_preserves_author_metadata_but_forces_unlisted
    write_source("[资料](first.md)")
    File.write(File.join(@source_dir, "first.md"), "---\ntitle: 人工资料\nai_generated: false\nsearch_exclude: false\npermalink: /\n---\ntext")
    importer = publisher
    result = importer.plan
    importer.write
    note = File.read(File.join(@repo, result[:references].first[:destination]))
    assert_includes note, "ai_generated: false"
    assert_includes note, "search_exclude: true"
    assert_match(%r{permalink: ["']?/references/}, note)
  end

  def test_reference_assets_and_markdown_sizes_are_checked
    write_source("[[first]]")
    File.write(File.join(@source_dir, "first.md"), "![图](attachments/my%20image.png)")
    assert_includes assert_raises(RuntimeError) { publisher(image_mb: 0.000001).plan }.message, "资源过大"
    assert_includes assert_raises(RuntimeError) { publisher(attachment_mb: 0.000001).plan }.message, "引用文章过大"
    assert_includes assert_raises(RuntimeError) { publisher(total_mb: 0.000001).plan }.message, "资源合计"
  end

  def test_hidden_reference_can_be_reused_by_another_publication
    write_source("[[first]]")
    File.write(File.join(@source_dir, "first.md"), "reference")
    first = publisher
    result = first.plan
    first.write
    second = publisher(slug: "another-post")
    assert_equal result[:references].first[:url], second.plan[:references].first[:url]
    second.write
    assert_equal 1, Dir.children(File.join(@repo, "_ai_articles")).size
  end

  def test_ai_category_and_legacy_field_produce_ai_documents_with_topic_categories
    File.write(@source, "---\ntitle: AI 分析\ncategories: [ai, tech]\n---\nbody")
    importer = publisher
    result = importer.plan
    assert_equal "ai", result[:kind]
    importer.write
    metadata = YAML.safe_load(File.read(File.join(@repo, result[:post])).split("---", 3)[1])
    assert_equal ["tech"], metadata["categories"]
    assert_equal true, metadata["ai_generated"]
    assert_equal false, metadata["reference_only"]
    assert_equal true, metadata["search_exclude"]
    write_source("body")
    assert_equal "post", publisher(slug: "ordinary").plan[:kind]
  end

  def test_same_ai_file_and_assets_have_same_url_from_standalone_and_reference_publishing
    ai = File.join(@source_dir, "analysis.md")
    File.write(ai, "---\ntitle: 分析\ncategories: [tech]\nai_generated: true\n---\n![[my image.png|300]]")
    write_source("![[my image.png]]\n[[analysis]]")
    importer = publisher
    via_reference = importer.plan
    importer.write
    direct = PostPublisher.new(source: ai, repo: @repo)
    via_direct = direct.plan
    assert_equal via_reference[:references].first[:url], via_direct[:url]
    direct.write
    assert_equal 1, Dir.children(File.join(@repo, "_ai_articles")).size
  end

  def test_ai_slug_conflicts_and_conflicting_markers_fail_without_writes
    File.write(@source, "---\ntitle: AI\ncategories: [ai, tech]\nai_generated: false\n---\ntext")
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "冲突"
    File.write(@source, "---\ntitle: AI\ncategories: [ai, tech]\nslug: shared\n---\nfirst")
    first = PostPublisher.new(source: @source, repo: @repo)
    first.plan
    first.write
    File.write(@source, File.read(@source).sub("first", "second"))
    assert_includes assert_raises(RuntimeError) { PostPublisher.new(source: @source, repo: @repo).plan }.message, "冲突"
  end

  def test_same_batch_ai_slug_conflicts_fail_before_writing
    write_source("[[first]]\n[[second]]")
    %w[first second].each do |name|
      File.write(File.join(@source_dir, "#{name}.md"), "---\ntitle: #{name}\ncategories: [ai, tech]\nslug: conflict\n---\n#{name}")
    end
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "slug 冲突"
    refute File.exist?(File.join(@repo, "_ai_articles"))
  end

  def test_html_is_compiled_to_data_and_unlisted_viewer_with_local_dependencies
    write_source("[演示](demo.html)")
    File.write(File.join(@source_dir, "demo.html"), '<html><head><link rel="stylesheet" href="style.css"></head><body><button id="b">click</button><img src="attachments/my%20image.png"><script src="demo.js"></script></body></html>')
    File.write(File.join(@source_dir, "style.css"), 'body { color: red; }')
    File.write(File.join(@source_dir, "demo.js"), 'document.querySelector("#b").onclick = () => { document.querySelector("#b").textContent = "clicked"; };')
    importer = publisher
    result = importer.plan
    assert_equal 1, result[:html_documents].size
    assert_empty result[:resources]
    item = result[:html_documents].first
    assert_equal 4, item[:dependencies].size
    importer.write
    payload = JSON.parse(File.read(File.join(@repo, item[:payload_destination])))
    assert_equal 1, payload["version"]
    assert_includes payload["html"], 'onclick'
    assert_includes payload["html"], 'data:image/png;base64,'
    refute_includes payload["html"], 'src="demo.js"'
    page = File.read(File.join(@repo, item[:destination]))
    assert_includes page, "search_exclude: true"
    assert_includes page, "reference_only: true"
    assert_includes File.read(File.join(@repo, result[:post])), item[:url]
    refute File.exist?(File.join(@repo, "demo.html"))
  end

  def test_html_missing_remote_or_oversized_dependencies_fail_before_writing
    write_source("[演示](demo.html)")
    html = File.join(@source_dir, "demo.html")
    File.write(html, '<script src="https://example.com/demo.js"></script>')
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "外部资源"
    File.write(html, '<img src="missing.png">')
    assert_includes assert_raises(RuntimeError) { publisher.plan }.message, "找不到 HTML 资源"
    File.write(html, '<img src="attachments/my%20image.png">')
    assert_includes assert_raises(RuntimeError) { publisher(image_mb: 0.000001).plan }.message, "HTML 资源过大"
    File.write(html, '<button>click</button>')
    assert_includes assert_raises(RuntimeError) { publisher(total_mb: 0.000001).plan }.message, "超限"
    refute File.exist?(File.join(@repo, "_html_documents"))
  end
end

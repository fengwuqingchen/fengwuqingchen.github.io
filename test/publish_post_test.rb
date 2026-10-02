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
    assert_includes article, "[my image.png](/assets/posts/"
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
    write_source("[网页](page.html)")
    File.write(File.join(@source_dir, "page.html"), "<script>demo</script>")
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
    assert_equal 2, Dir.children(File.join(@repo, "_references")).size
    root = File.read(File.join(@repo, result[:post]))
    assert_equal 3, root.scan(%r{\(/references/}).size
    result[:references].each do |note|
      content = File.read(File.join(@repo, note[:destination]))
      assert_includes content, "ai_generated: true"
      assert_includes content, "reference_only: true"
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
    importer = publisher
    result = importer.plan
    assert_equal "_references/test-post.md", result[:post]
    assert_equal "/references/test-post/", result[:url]
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
    assert_equal 1, Dir.children(File.join(@repo, "_references")).size
  end
end

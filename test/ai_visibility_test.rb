# frozen_string_literal: true

require "minitest/autorun"
require "yaml"
require "date"

class AiVisibilityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_ai_and_html_are_not_posts_and_are_excluded_from_global_search_and_feed
    config = YAML.safe_load(File.read(File.join(ROOT, "_config.yml")))
    %w[ai_articles html_documents].each do |type|
      assert_equal true, config.fetch("collections").fetch(type).fetch("output")
      defaults = config.fetch("defaults").find { |entry| entry.fetch("scope")["type"] == type }
      assert_equal true, defaults.fetch("values")["search_exclude"]
    end
    refute config.fetch("feed").key?("collections")
    assert_includes File.read(File.join(ROOT, "_layouts/default.html")), "'/ai/'"
    ai = File.read(File.join(ROOT, "_layouts/ai-list.html"))
    assert_includes ai, "site.ai_articles"
    assert_includes ai, "post.categories contains page.category_slug"
    %w[index.html categories.html _layouts/category.html].each do |path|
      source = File.read(File.join(ROOT, path))
      assert_includes source, "site.posts"
      refute_includes source, 'where: "ai_generated", false'
    end
  end

  def test_existing_articles_and_urls_remain_ordinary_without_new_required_fields
    posts = Dir[File.join(ROOT, "_posts", "*.md")]
    assert_operator posts.size, :>=, 5
    posts.each do |path|
      metadata = YAML.safe_load(File.read(path).split("---", 3)[1], permitted_classes: [Date, Time])
      refute_equal true, metadata["ai_generated"]
    end
    assert_includes File.read(File.join(ROOT, "_config.yml")), "permalink: /posts/:title/"
  end

  def test_html_viewer_does_not_publish_executable_source_or_grant_origin_permissions
    viewer = File.read(File.join(ROOT, "assets/js/html-viewer.js"))
    assert_includes viewer, "setAttribute('sandbox', 'allow-scripts')"
    refute_match(/setAttribute\('sandbox', '[^']*allow-same-origin/, viewer)
    assert_includes viewer, "connect-src 'none'"
    assert_includes viewer, "credentials: 'omit'"
    assert_includes viewer, "frame.srcdoc"
    assert_includes viewer, "container.replaceChildren()"
    layout = File.read(File.join(ROOT, "_layouts/html-reference.html"))
    assert_includes layout, "data-html-load"
    refute_includes layout, "{{ content }}"
  end
end

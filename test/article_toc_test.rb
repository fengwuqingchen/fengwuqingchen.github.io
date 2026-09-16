# frozen_string_literal: true

require "minitest/autorun"

class ArticleTocTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_post_layout_has_an_accessible_article_outline
    layout = read("_layouts/post.html")

    assert_includes layout, "article-layout"
    assert_includes layout, "data-article-toc"
    assert_includes layout, "data-article-toc-list"
    assert_includes layout, 'aria-label="文章目录"'
    assert_includes layout, "assets/js/article-toc.js"
  end

  def test_outline_script_builds_links_for_markdown_heading_levels
    script = read("assets/js/article-toc.js")

    assert_includes script, ".prose h2, .prose h3, .prose h4"
    assert_includes script, "heading.id"
    assert_includes script, "heading-anchor"
    assert_includes script, "IntersectionObserver"
  end

  def test_outline_styles_keep_hash_targets_clear_of_the_sticky_header
    stylesheet = read("assets/css/style.css")

    assert_match(/\.article-layout\s*\{[^}]*grid-template-columns/m, stylesheet)
    assert_match(/\.article-toc\s*\{[^}]*position:\s*sticky/m, stylesheet)
    assert_match(/\.prose h2,[^{]*\{[^}]*scroll-margin-top/m, stylesheet)
    assert_includes stylesheet, "@media (max-width: 1120px)"
  end

  def test_writing_guide_explains_heading_links_and_toc_levels
    guide = read("README.md")

    assert_includes guide, "文章目录与标题链接"
    assert_includes guide, "## 二级标题"
    assert_includes guide, "### 三级标题"
  end

  private

  def read(relative_path)
    File.read(File.join(ROOT, relative_path))
  end
end

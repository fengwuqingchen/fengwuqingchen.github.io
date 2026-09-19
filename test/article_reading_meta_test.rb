# frozen_string_literal: true

require "minitest/autorun"

class ArticleReadingMetaTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_post_layout_calculates_character_count_and_reading_time_from_each_article_body
    layout = read("_layouts/post.html")

    assert_includes layout, "assign article_plaintext"
    assert_includes layout, "strip_html"
    assert_includes layout, "strip_newlines"
    assert_includes layout, 'replace: " ", ""'
    assert_includes layout, "assign article_character_count"
    assert_includes layout, "plus: 399"
    assert_includes layout, "divided_by: 400"
  end

  def test_post_layout_places_reading_metadata_in_the_requested_header_line
    layout = read("_layouts/post.html")

    assert_includes layout, "post-reading-meta"
    assert_includes layout, "data-article-word-count"
    assert_includes layout, "data-article-reading-time"
    assert_includes layout, "字"
    assert_includes layout, "预计"
    assert_includes layout, "分钟"
    assert_operator layout.index("post-reading-meta"), :<, layout.index("data-page-views")
  end

  def test_reading_metadata_preserves_the_compact_terminal_metadata_style
    stylesheet = read("assets/css/style.css")

    assert_match(/\.post-reading-meta\s*\{[^}]*display:\s*inline-flex/m, stylesheet)
    assert_match(/\.post-reading-meta\s*\{[^}]*font-family:\s*var\(--mono\)/m, stylesheet)
  end

  def test_writing_guide_explains_that_metadata_is_automatic
    guide = read("README.md")

    assert_includes guide, "字数与预计阅读时间"
    assert_includes guide, "400"
    assert_includes guide, "无需在文章 YAML 中填写"
  end

  private

  def read(relative_path)
    File.read(File.join(ROOT, relative_path))
  end
end

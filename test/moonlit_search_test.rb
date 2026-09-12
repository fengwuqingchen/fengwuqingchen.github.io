# frozen_string_literal: true

require "json"
require "minitest/autorun"

class MoonlitSearchTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_homepage_uses_the_requested_moonlit_statement_and_inline_svg
    homepage = read("index.html")

    assert_includes homepage, "唤起一天明月"
    assert_includes homepage, "照我满怀冰雪"
    assert_match(/<svg[^>]+class="[^"]*moon-scene/, homepage)
    assert_includes homepage, "<title id=\"moon-scene-title\">"
  end

  def test_search_is_available_as_an_accessible_dialog
    layout = read("_layouts/default.html")

    assert_includes layout, "data-search-open"
    assert_includes layout, "role=\"dialog\""
    assert_includes layout, "aria-modal=\"true\""
    assert_includes layout, "id=\"search-input\""
    assert_includes layout, "id=\"search-results\""
    assert_includes layout, "assets/js/search.js"
  end

  def test_post_content_is_scoped_for_search_indexing
    post_layout = read("_layouts/post.html")

    assert_includes post_layout, "data-pagefind-body"
    assert_includes post_layout, "data-pagefind-meta=\"title\""
    assert_includes post_layout, "data-pagefind-filter=\"category"
    assert_includes post_layout, "data-pagefind-meta=\"date"
  end

  def test_search_script_supports_keyboard_and_empty_states
    script = read("assets/js/search.js")

    assert_includes script, "import("
    assert_includes script, "pagefind.js"
    assert_includes script, "event.key === \"/\""
    assert_includes script, "event.key === \"Escape\""
    assert_includes script, "没有找到相关内容"
    assert_includes script, "请输入标题、正文或分类关键词"
  end

  def test_pagefind_is_pinned_and_runs_after_the_jekyll_build
    package = JSON.parse(read("package.json"))
    workflow = read(".github/workflows/pages.yml")

    assert_match(/\A\d+\.\d+\.\d+\z/, package.fetch("devDependencies").fetch("pagefind"))
    assert_includes package.fetch("scripts").fetch("search:index"), "pagefind --site _site"
    assert_includes workflow, "actions/jekyll-build-pages@v1"
    assert_includes workflow, 'sudo chown -R "$USER":"$USER" _site'
    assert_includes workflow, "npm run search:index"
    assert_operator workflow.index("actions/jekyll-build-pages@v1"), :<, workflow.index("npm run search:index")
    assert_operator workflow.index('sudo chown -R "$USER":"$USER" _site'), :<, workflow.index("npm run search:index")
    assert_includes workflow, "actions/deploy-pages@v4"
  end

  def test_motion_has_a_reduced_motion_fallback
    stylesheet = read("assets/css/style.css")

    assert_includes stylesheet, "@media (prefers-reduced-motion: reduce)"
    assert_includes stylesheet, "animation: none"
  end

  private

  def read(relative_path)
    File.read(File.join(ROOT, relative_path))
  end
end

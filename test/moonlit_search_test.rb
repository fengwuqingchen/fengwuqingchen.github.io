# frozen_string_literal: true

require "json"
require "minitest/autorun"

class MoonlitSearchTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_homepage_uses_the_requested_statement_without_extra_slogan
    homepage = read("index.html")

    assert_includes homepage, "唤起一天明月"
    assert_includes homepage, "照我满怀冰雪"
    refute_includes homepage, "在喧闹之外"
    assert_includes homepage, "terminal-line"
    assert_includes homepage, "$ cat ./intro.md"
  end

  def test_moon_is_a_fixed_site_wide_background
    layout = read("_layouts/default.html")
    stylesheet = read("assets/css/style.css")

    assert_includes layout, "site-atmosphere"
    assert_includes layout, "moon-backdrop"
    assert_includes layout, "<title id=\"moon-backdrop-title\">"
    assert_match(/\.site-atmosphere\s*\{[^}]*position:\s*fixed/m, stylesheet)
  end

  def test_light_and_dark_themes_are_user_selectable_and_persisted
    layout = read("_layouts/default.html")
    script = read("assets/js/theme.js")
    stylesheet = read("assets/css/style.css")

    assert_includes layout, "data-theme-toggle"
    assert_includes layout, "assets/js/theme.js"
    assert_includes script, "prefers-color-scheme: dark"
    assert_includes script, "localStorage"
    assert_includes stylesheet, '[data-theme="dark"]'
  end

  def test_terminal_language_and_a_long_search_control_are_visible
    layout = read("_layouts/default.html")
    stylesheet = read("assets/css/style.css")

    assert_includes layout, "&gt;_"
    assert_includes layout, "STATUS: ONLINE"
    assert_match(/\.search-trigger\s*\{[^}]*width:\s*clamp\(/m, stylesheet)
  end

  def test_article_uses_a_centered_reading_column_and_quiet_header
    post_layout = read("_layouts/post.html")
    stylesheet = read("assets/css/style.css")

    assert_includes post_layout, "reading-shell"
    assert_includes post_layout, "article-path"
    assert_match(/\.reading-shell\s*\{[^}]*max-width:\s*760px/m, stylesheet)
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

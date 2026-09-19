# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class PageViewCounterTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_goatcounter_endpoint_is_configured_without_exposing_credentials
    config = YAML.safe_load(read("_config.yml"))
    endpoint = config.fetch("analytics").fetch("goatcounter_endpoint")

    assert_equal "https://fengqing.goatcounter.com/count", endpoint
    refute_match(/password|token|secret/i, endpoint)
  end

  def test_tracking_script_is_loaded_once_for_the_site
    layout = read("_layouts/default.html")

    assert_includes layout, "site.analytics.goatcounter_endpoint"
    assert_includes layout, 'id="goatcounter-script"'
    assert_includes layout, 'src="https://gc.zgo.at/count.js"'
    assert_includes layout, 'data-goatcounter="{{ site.analytics.goatcounter_endpoint }}"'
  end

  def test_articles_have_an_accessible_placeholder_for_page_views
    layout = read("_layouts/post.html")

    assert_includes layout, "data-page-views"
    assert_includes layout, 'aria-live="polite"'
    assert_includes layout, "assets/js/page-views.js"
  end

  def test_view_counter_fetches_the_current_canonical_path_and_fails_quietly
    script = read("assets/js/page-views.js")

    assert_includes script, "goatcounter-script"
    assert_includes script, "get_data"
    assert_includes script, "encodeURIComponent(path)"
    assert_includes script, "/counter/"
    assert_includes script, ".json"
    assert_includes script, "fetch("
    assert_includes script, "浏览"
  end

  def test_view_counter_uses_the_existing_quiet_article_metadata_language
    stylesheet = read("assets/css/style.css")

    assert_match(/\.post-views\s*\{[^}]*font-family:\s*var\(--mono\)/m, stylesheet)
    assert_match(/\.post-views\s*\{[^}]*color:\s*var\(--muted\)/m, stylesheet)
  end

  private

  def read(relative_path)
    File.read(File.join(ROOT, relative_path))
  end
end

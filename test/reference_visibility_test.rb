# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class ReferenceVisibilityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_references_are_an_output_collection_separate_from_posts_and_feed
    config = YAML.safe_load(File.read(File.join(ROOT, "_config.yml")))
    assert_equal true, config.fetch("collections").fetch("references").fetch("output")
    defaults = config.fetch("defaults").find { |item| item.fetch("scope")["type"] == "references" }
    assert_equal true, defaults.fetch("values").fetch("search_exclude")
    assert_equal true, defaults.fetch("values").fetch("reference_only")
    refute config.fetch("feed").key?("collections")
    %w[index.html categories.html].each do |filename|
      template = File.read(File.join(ROOT, filename))
      assert_includes template, "site.posts"
      refute_includes template, "site.references"
    end
  end

  def test_reference_pages_are_excluded_from_search_and_marked_for_readers
    layout = File.read(File.join(ROOT, "_layouts/default.html"))
    assert_includes layout, 'if page.search_exclude'
    assert_includes layout, 'data-pagefind-ignore="all"'
    assert_includes layout, 'if page.reference_only'
    assert_includes layout, 'content="noindex, nofollow"'
    article = File.read(File.join(ROOT, "_layouts/post.html"))
    assert_includes article, "AI 生成的引用资料"
    assert_includes article, "~/references/"
  end
end

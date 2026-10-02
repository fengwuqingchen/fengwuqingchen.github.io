# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../scripts/generate-category-pages"

class CategoryPagesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_every_yaml_category_gets_a_page_including_empty_categories
    Dir.mktmpdir("category-pages-") do |repo|
      FileUtils.mkdir_p(File.join(repo, "_data"))
      FileUtils.cp(File.join(ROOT, "_data/categories.yml"), File.join(repo, "_data/categories.yml"))
      generate_category_pages(repo)
      categories = YAML.safe_load(File.read(File.join(repo, "_data/categories.yml")))
      categories.each do |category|
        content = File.read(File.join(repo, "generated-categories", "#{category.fetch('slug')}.html"))
        metadata = YAML.safe_load(content.split("---", 3)[1])
        assert_equal "category", metadata["layout"]
        assert_equal category["slug"], metadata["category_slug"]
        assert_equal "/categories/#{category['slug']}/", metadata["permalink"]
        assert_equal true, metadata["search_exclude"]
      end
    end
  end

  def test_links_target_individual_category_pages_and_layout_filters_posts
    %w[categories.html _includes/category-labels.html].each do |path|
      content = File.read(File.join(ROOT, path))
      assert_includes content, "append: category.slug | append: '/'"
    end
    layout = File.read(File.join(ROOT, "_layouts/category.html"))
    assert_includes layout, 'post.categories contains page.category_slug'
    assert_includes layout, 'site.posts'
    refute_includes layout, 'site.references'
    assert_includes layout, '这个分类还没有文章'
    assert_includes File.read(File.join(ROOT, '.github/workflows/pages.yml')), 'ruby scripts/generate-category-pages.rb'
  end
end

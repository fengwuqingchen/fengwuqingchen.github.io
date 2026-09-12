# frozen_string_literal: true

require "date"
require "minitest/autorun"
require "yaml"

class CategorySupportTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_categories_are_centrally_configured_in_yaml
    categories = load_yaml("_data/categories.yml")

    assert_kind_of Array, categories
    refute_empty categories

    slugs = categories.map { |category| category.fetch("slug") }
    names = categories.map { |category| category.fetch("name") }

    assert_equal slugs.uniq, slugs, "category slugs must be unique"
    assert_equal names.uniq, names, "category names must be unique"
    assert slugs.all? { |slug| slug.match?(/\A[a-z0-9-]+\z/) }
  end

  def test_every_post_category_exists_in_the_yaml_catalog
    category_slugs = load_yaml("_data/categories.yml").map { |category| category.fetch("slug") }

    post_front_matters.each do |path, front_matter|
      categories = Array(front_matter["categories"])
      refute_empty categories, "#{path} must declare at least one category"

      unknown = categories - category_slugs
      assert_empty unknown, "#{path} references undefined categories: #{unknown.join(', ')}"
    end
  end

  def test_readers_can_open_the_category_archive_from_the_main_navigation
    default_layout = read("_layouts/default.html")
    category_page = read("categories.html")

    assert_includes default_layout, "'/categories/'"
    assert_includes category_page, "site.data.categories"
    assert_includes category_page, "post.categories contains category.slug"
  end

  def test_category_links_are_rendered_on_post_cards_and_articles
    include_template = read("_includes/category-labels.html")

    assert_includes include_template, "site.data.categories"
    assert_includes include_template, "include.categories"
    assert_includes read("index.html"), "include category-labels.html"
    assert_includes read("_layouts/post.html"), "include category-labels.html"
  end

  private

  def load_yaml(relative_path)
    YAML.safe_load(read(relative_path), permitted_classes: [Date, Time])
  end

  def read(relative_path)
    File.read(File.join(ROOT, relative_path))
  end

  def post_front_matters
    Dir[File.join(ROOT, "_posts", "*.md")].to_h do |path|
      front_matter = File.read(path).split("---", 3).fetch(1)
      [path.delete_prefix("#{ROOT}/"), YAML.safe_load(front_matter, permitted_classes: [Date, Time])]
    end
  end
end

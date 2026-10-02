#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "fileutils"

# Generate ordinary Jekyll pages rather than requiring a custom Jekyll plugin.
def generate_category_pages(repo)
  categories = YAML.safe_load(File.read(File.join(repo, "_data/categories.yml")))
  slugs = categories.map { |category| category.fetch("slug") }
  raise "分类 slug 必须唯一且仅包含小写字母、数字和短横线" unless slugs.uniq == slugs && slugs.all? { |slug| slug.is_a?(String) && slug.match?(/\A[a-z0-9-]+\z/) }
  destination = File.join(repo, "generated-categories")
  FileUtils.mkdir_p(destination)
  categories.each do |category|
    metadata = { "layout" => "category", "title" => "#{category.fetch('name')} · 文章分类",
                 "category_slug" => category.fetch("slug"), "search_exclude" => true,
                 "permalink" => "/categories/#{category.fetch('slug')}/" }
    File.write(File.join(destination, "#{category.fetch('slug')}.html"), "#{YAML.dump(metadata)}---\n")
  end
end

generate_category_pages(File.expand_path("..", __dir__)) if $PROGRAM_NAME == __FILE__

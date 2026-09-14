# frozen_string_literal: true

require "minitest/autorun"

class CopyrightNoticeTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_every_page_footer_links_to_the_rights_notice
    layout = read("_layouts/default.html")

    assert_includes layout, "All Rights Reserved"
    assert_includes layout, "'/copyright/'"
    assert_includes layout, "版权与转载"
  end

  def test_rights_page_explains_reprint_and_quotation_rules
    page = read("copyright.md")

    assert_includes page, "permalink: /copyright/"
    assert_includes page, "保留所有权利"
    assert_includes page, "未经书面许可"
    assert_includes page, "合理引用"
    assert_includes page, "1958898938@qq.com"
  end

  def test_repository_license_does_not_grant_mit_reuse_rights
    license = read("LICENSE")

    assert_includes license, "All Rights Reserved"
    refute_includes license, "MIT License"
  end

  private

  def read(relative_path)
    File.read(File.join(ROOT, relative_path))
  end
end

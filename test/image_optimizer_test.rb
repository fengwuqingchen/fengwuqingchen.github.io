# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "zlib"
require_relative "../scripts/image-optimizer"

class ImageOptimizerTest < Minitest::Test
  def png
    chunk = lambda { |name, data| [data.bytesize].pack("N") + name + data + [Zlib.crc32(name + data)].pack("N") }
    pixels = ("\x00".b + "\xff\x00\x00\xff".b * 128) * 128
    "\x89PNG\r\n\x1a\n".b + chunk.call("IHDR", [128, 128, 8, 6, 0, 0, 0].pack("NNCCCCC")) + chunk.call("IDAT", Zlib::Deflate.deflate(pixels)) + chunk.call("IEND", "")
  end

  def test_real_lossless_compression_is_smaller_and_preserves_source
    Dir.mktmpdir("image-optimizer-") do |dir|
      path = File.join(dir, "image.png")
      original = png
      File.binwrite(path, original)
      result = ImageOptimizer.optimize(path)
      if result[:compression] == "cwebp-unavailable-original"
        assert_equal original, result[:bytes]
      else
        assert_equal "lossless-webp", result[:compression]
        assert_operator result[:bytes].bytesize, :<, original.bytesize
        assert_equal ".webp", result[:extension]
      end
      assert_equal original, File.binread(path)
      assert_equal original, ImageOptimizer.optimize(path, enabled: false)[:bytes]
    end
  end

  def test_animation_photos_and_invalid_images_are_not_transcoded
    Dir.mktmpdir("image-optimizer-") do |dir|
      jpg = File.join(dir, "photo.jpg")
      File.binwrite(jpg, "jpeg-test")
      assert_equal "jpeg-test", ImageOptimizer.optimize(jpg)[:bytes]
      image = png
      animation = [8].pack("N") + "acTL" + [2, 0].pack("NN") + [0].pack("N")
      path = File.join(dir, "animated.png")
      File.binwrite(path, image[0, 33] + animation + image[33..])
      assert_equal "original", ImageOptimizer.optimize(path)[:compression]
      high_precision = png
      high_precision.setbyte(24, 16)
      File.binwrite(path, high_precision)
      assert_equal high_precision, ImageOptimizer.optimize(path)[:bytes]
      File.binwrite(path, "invalid")
      assert_equal "invalid", ImageOptimizer.optimize(path)[:bytes]
    end
  end
end

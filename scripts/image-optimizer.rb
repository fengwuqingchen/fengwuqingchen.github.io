# frozen_string_literal: true

require "tempfile"
require "timeout"

# Lossless only: never resize or re-encode photos lossily. Originals stay intact.
module ImageOptimizer
  def self.optimize(path, enabled: true)
    original = File.binread(path)
    result = { bytes: original, extension: File.extname(path).downcase, compression: "original" }
    return result.merge(compression: "disabled") unless enabled
    # Avoid destroying animation, orientation, HDR, or vector information.
    return result unless result[:extension] == ".png" && original.start_with?("\x89PNG\r\n\x1a\n".b)
    return result if animated_png?(original)
    Tempfile.create(["blog-image-", ".webp"]) do |output|
      begin
        pid = Process.spawn("cwebp", "-lossless", "-exact", "-metadata", "all", "-m", "4", "-quiet",
                            path, "-o", output.path, out: File::NULL, err: File::NULL)
        status = nil
        begin
          Timeout.timeout(30) { _, status = Process.wait2(pid) }
        rescue Timeout::Error
          Process.kill("KILL", pid) rescue nil
          Process.wait(pid) rescue nil
          return result.merge(compression: "timeout-original")
        end
        return result.merge(compression: "failed-original") unless status.success?
        compressed = File.binread(output.path)
        return result unless compressed.bytesize < original.bytesize && compressed.start_with?("RIFF") && compressed[8, 4] == "WEBP"
        result = { bytes: compressed, extension: ".webp", compression: "lossless-webp" }
      rescue Errno::ENOENT
        result = result.merge(compression: "cwebp-unavailable-original")
      end
    end
    result
  end

  def self.animated_png?(data)
    offset = 8
    while offset + 12 <= data.bytesize
      length = data[offset, 4].unpack1("N")
      type = data[offset + 4, 4]
      return true if type == "acTL"
      break if type == "IEND"
      offset += length + 12
    end
    false
  end
end

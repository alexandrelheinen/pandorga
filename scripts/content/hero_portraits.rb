# frozen_string_literal: true

# The home hero pool is the folder. The content export writes the public
# paths to pages/home/portraits.json. The author uploads a photograph under
# content/media/images/hero/ and does not keep a second list.
# The plate is 16:9 at every width (PLT-AC-51). The export writes 16:9 width
# variants under variants/ with the project thumbnail generator
# (Pandorga::ThumbnailVariants), so they are not extra draws. An entry lists
# only the variants that are 16:9: the old 3:4 hero variants had the same
# names and must not reach srcset when ImageMagick could not replace them.

require "pathname"

module HeroPortraits
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp .gif].freeze
  WIDTHS = [480, 960, 1440].freeze
  # Below 1024px the plate spans the column (edge to edge on a phone); from
  # 1024px it takes a little under half the row.
  SIZES = "(max-width: 1023px) 100vw, 50vw"

  module_function

  def entries(content_root)
    root = Pathname.new(content_root)
    image_files(root).map do |file|
      entry = { "src" => "/media/images/hero/#{file.basename}" }
      stem = file.basename.to_s.sub(/\.[^.]+\z/, "")
      parts = WIDTHS.filter_map do |width|
        variant = root.join("media/images/hero/variants/#{stem}-#{width}.jpg")
        next unless variant.file? && wide?(variant)

        "/media/images/hero/variants/#{variant.basename} #{width}w"
      end
      next entry if parts.empty?

      entry.merge("srcset" => parts.join(", "), "sizes" => SIZES)
    end
  end

  def image_files(root)
    dir = root.join("media/images/hero")
    return [] unless dir.directory?

    dir.children.select do |path|
      path.file? && IMAGE_EXTENSIONS.include?(path.extname.downcase)
    end.sort_by { |path| path.basename.to_s }
  end

  # True when the file is 16:9 to within a pixel.
  def wide?(path)
    size = image_size(path)
    return false unless size

    width, height = size
    width.positive? && (height - (width * 9 / 16.0)).abs <= 1
  end

  # [width, height] from a JPEG or PNG header, sniffed by content, or nil.
  def image_size(path)
    File.open(path, "rb") do |io|
      head = io.read(24).to_s
      if head.start_with?("\x89PNG\r\n\x1A\n".b) && head.byteslice(12, 4) == "IHDR"
        return head.byteslice(16, 8).unpack("NN")
      end
      return nil unless head.start_with?("\xFF\xD8".b)

      jpeg_size(io)
    end
  rescue StandardError
    nil
  end

  def jpeg_size(io)
    io.seek(2)
    loop do
      byte = io.read(1)
      return nil unless byte
      next unless byte.ord == 0xFF

      marker = io.read(1)&.ord
      return nil unless marker
      next if marker == 0xFF || marker == 0x01 || (0xD0..0xD8).cover?(marker)
      return nil if marker == 0xD9 || marker == 0xDA

      length = io.read(2)&.unpack1("n")
      return nil unless length && length >= 2

      if (0xC0..0xCF).cover?(marker) && ![0xC4, 0xC8, 0xCC].include?(marker)
        data = io.read(5)
        return nil unless data && data.bytesize == 5

        height, width = data.byteslice(1, 4).unpack("nn")
        return [width, height]
      end
      io.seek(length - 2, IO::SEEK_CUR)
    end
  end
end

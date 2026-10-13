# frozen_string_literal: true

# The home hero pool is the folder. The content export writes the public
# paths to pages/home/portraits.json. The author uploads a photograph under
# content/media/images/hero/ and does not keep a second list.
# Optional width variants live under variants/ so they are not extra draws.
# Variants should be 3:4 portrait fills (not landscape width-only resizes):
# the plate is object-fit cover at 3:4, including on a phone, so a 480×270
# landscape candidate is too short and looks soft. A separate 16:9 file for
# narrow viewports is pandorga.home.hero_landscape, not a pool variant.

require "pathname"

module HeroPortraits
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp .gif].freeze
  WIDTHS = [480, 960, 1440].freeze
  # Slightly above the plate CSS width (14/16rem at html 110%) so 1.75–2×
  # DPR picks the next 3:4 variant instead of a soft 480w. Variants must be
  # portrait fills; landscape width-only resizes are too short under cover.
  SIZES = "(max-width: 767px) 100vw, (max-width: 1023px) 18rem, 20rem"

  module_function

  def entries(content_root)
    root = Pathname.new(content_root)
    image_files(root).map do |file|
      entry = { "src" => "/media/images/hero/#{file.basename}" }
      stem = file.basename.to_s.sub(/\.[^.]+\z/, "")
      parts = WIDTHS.filter_map do |width|
        variant = root.join("media/images/hero/variants/#{stem}-#{width}.jpg")
        next unless variant.file?

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
end

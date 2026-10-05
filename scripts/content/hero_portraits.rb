# frozen_string_literal: true

# The home hero pool is the folder. The content export writes the public
# paths to pages/home/portraits.json. The author uploads a photograph under
# content/media/images/hero/ and does not keep a second list.

require "pathname"

module HeroPortraits
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp .gif].freeze

  module_function

  def entries(content_root)
    image_files(Pathname.new(content_root)).map do |file|
      { "src" => "/media/images/hero/#{file.basename}" }
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

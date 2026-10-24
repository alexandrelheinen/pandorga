# frozen_string_literal: true

require "date"
require "fileutils"
require "open3"
require "pathname"
require "set"
require "time"
require "yaml"

require_relative "registry"

module Pandorga
  # Generates 16:9 center-cropped width variants for local project thumbnails
  # and the home hero photographs, and computes their srcset strings.
  # Refs: PLT-AC-44, PLT-AC-51
  module ThumbnailVariants
    WIDTHS = [480, 960, 1440].freeze
    IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
    QUALITY = 82

    module_function

    def generate(site_root)
      root = Pathname.new(site_root).expand_path
      content_root = resolve_content_root(root)
      sources = project_thumbnail_sources(root, content_root)
      hero_sources(content_root).each do |src|
        sources << src unless sources.any? { |known| known.expand_path == src.expand_path }
      end

      summary = { sources: sources.length, written: 0, skipped: 0, failed: 0 }
      return summary if sources.empty?

      bins = resolve_imagemagick
      unless bins
        warn "warning: ImageMagick (magick or convert) not found; skipping project thumbnail variants"
        return summary
      end

      sources.each do |src|
        src_width = identify_width(bins[:identify], src)
        unless src_width && src_width.positive?
          # An unreadable image keeps its original and must not stop the export.
          warn "warning: cannot read #{src}; skipping its thumbnail variants"
          summary[:failed] += 1
          next
        end

        stem = src.basename(src.extname).to_s
        variants_dir = src.dirname.join("variants")
        src_mtime = src.mtime

        WIDTHS.each do |width|
          if width > src_width
            summary[:skipped] += 1
            next
          end

          dest = variants_dir.join("#{stem}-#{width}.jpg")
          # A newer variant is kept only when it is already this 16:9 size.
          # Hero variants used to be 3:4 under the same names.
          if dest.file? && dest.mtime >= src_mtime &&
             identify_size(bins[:identify], dest) == [width, (width * 9) / 16]
            summary[:skipped] += 1
            next
          end

          begin
            write_variant(bins[:convert], src, dest, width)
            summary[:written] += 1
          rescue StandardError => e
            warn "warning: #{e.message.lines.first.to_s.strip}; keeping the original only"
            summary[:failed] += 1
          end
        end
      end

      summary
    end

    def srcset_for(site_root, thumbnail_path)
      media_rel = normalize_local_media_path(thumbnail_path)
      return nil unless media_rel

      ext = File.extname(media_rel).downcase
      return nil unless IMAGE_EXTENSIONS.include?(ext)

      root = Pathname.new(site_root).expand_path
      content_root = resolve_content_root(root)
      src = content_root.join(media_rel.delete_prefix("/"))
      return nil unless src.file?

      stem = src.basename(src.extname).to_s
      variants_dir = src.dirname.join("variants")
      return nil unless variants_dir.directory?

      url_dir = File.dirname(media_rel)
      parts = WIDTHS.filter_map do |width|
        variant = variants_dir.join("#{stem}-#{width}.jpg")
        next unless variant.file?

        "#{url_dir}/variants/#{stem}-#{width}.jpg #{width}w"
      end
      return nil if parts.empty?

      parts.join(", ")
    end

    def resolve_content_root(root)
      candidate = root.join("content")
      return candidate if candidate.directory?
      return root if root.join("collections").directory? || root.join("media").directory?

      candidate
    end

    def project_collections(root)
      config_path = root.join("_config.yml")
      config = if config_path.file?
                 YAML.safe_load(config_path.read, permitted_classes: [Date, Time], aliases: true) || {}
               else
                 {}
               end
      pages = PandorgaRegistry.pages(config)
      names = pages.filter_map do |page|
        next unless page.is_a?(Hash) && page["template"].to_s == "portfolio"

        col = page["collection"].to_s.strip
        col = page.dig("collections", "projects").to_s.strip if col.empty? && page["collections"].is_a?(Hash)
        col unless col.empty?
      end.uniq
      names.empty? ? ["projects"] : names
    rescue StandardError
      ["projects"]
    end

    def project_thumbnail_sources(root, content_root)
      seen = Set.new
      sources = []

      project_collections(root).each do |collection|
        dir = content_root.join("collections", collection)
        next unless dir.directory?

        dir.glob("**/*.{md,markdown}").sort.each do |md_path|
          fm = read_front_matter(md_path)
          next if fm["published"] == false && ENV["CONTENT_EXPORT_INCLUDE_UNPUBLISHED"] != "1"

          media_rel = normalize_local_media_path(fm["thumbnail"])
          next unless media_rel
          next unless IMAGE_EXTENSIONS.include?(File.extname(media_rel).downcase)

          src = content_root.join(media_rel.delete_prefix("/"))
          next unless src.file?

          key = src.expand_path.to_s
          next if seen.include?(key)

          seen << key
          sources << src
        end
      end

      sources
    end

    # Every image directly in media/images/hero/ (the hero pool, PLT-AC-51).
    def hero_sources(content_root)
      dir = Pathname.new(content_root).join("media/images/hero")
      return [] unless dir.directory?

      dir.children.select do |path|
        path.file? && IMAGE_EXTENSIONS.include?(path.extname.downcase)
      end.sort_by { |path| path.basename.to_s }
    end

    def normalize_local_media_path(path)
      value = path.to_s.strip
      return nil if value.empty?
      return nil if value.match?(%r{\Ahttps?://}i)

      if value.start_with?("/content/media/")
        "/media/#{value.delete_prefix("/content/media/")}"
      elsif value.start_with?("content/media/")
        "/media/#{value.delete_prefix("content/media/")}"
      elsif value.start_with?("/media/")
        value
      elsif value.start_with?("media/")
        "/#{value}"
      end
    end

    def read_front_matter(path)
      text = path.read.sub(/\A\xEF\xBB\xBF/, "")
      return {} unless text.start_with?("---\n") || text.start_with?("---\r\n")

      parts = text.split(/^---\s*$\r?\n?/, 3)
      return {} unless parts.length == 3

      YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
    rescue StandardError
      {}
    end

    def resolve_imagemagick
      override = ENV["PANDORGA_IMAGEMAGICK"].to_s.strip
      unless override.empty?
        return nil unless executable_available?(override)

        return {
          convert: [override],
          identify: File.basename(override) == "magick" ? [override, "identify"] : [ resolve_companion_identify(override) ]
        }
      end

      if executable_available?("magick")
        { convert: ["magick"], identify: ["magick", "identify"] }
      elsif executable_available?("convert") && executable_available?("identify")
        { convert: ["convert"], identify: ["identify"] }
      end
    end

    def resolve_companion_identify(convert_bin)
      sibling = File.join(File.dirname(convert_bin), "identify")
      return sibling if File.executable?(sibling) && !File.directory?(sibling)

      "identify"
    end

    def executable_available?(bin)
      return false if bin.to_s.empty?

      if bin.include?("/")
        File.executable?(bin) && !File.directory?(bin)
      else
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          next false if dir.empty?

          candidate = File.join(dir, bin)
          File.executable?(candidate) && !File.directory?(candidate)
        end
      end
    end

    def identify_width(identify_cmd, src)
      cmd = [*identify_cmd, "-ping", "-format", "%w", "#{src}[0]"]
      out, _err, status = Open3.capture3(*cmd)
      return nil unless status.success?

      out.to_s.strip.to_i
    rescue StandardError
      nil
    end

    def identify_size(identify_cmd, src)
      cmd = [*identify_cmd, "-ping", "-format", "%w %h", "#{src}[0]"]
      out, _err, status = Open3.capture3(*cmd)
      return nil unless status.success?

      out.to_s.split.map(&:to_i)
    rescue StandardError
      nil
    end

    def write_variant(convert_cmd, src, dest, width)
      height = (width * 9) / 16
      FileUtils.mkdir_p(dest.dirname)
      tmp = dest.dirname.join(".#{dest.basename}.tmp-#{Process.pid}")
      cmd = [
        *convert_cmd,
        "#{src}[0]",
        "-auto-orient",
        "-resize", "#{width}x#{height}^",
        "-gravity", "center",
        "-extent", "#{width}x#{height}",
        "-strip",
        "-interlace", "JPEG",
        "-sampling-factor", "4:2:0",
        "-quality", QUALITY.to_s,
        "jpeg:#{tmp}"
      ]
      out, err, status = Open3.capture3(*cmd)
      unless status.success? && tmp.file?
        FileUtils.rm_f(tmp)
        raise "ImageMagick failed for #{src} (#{width}w): #{out}\n#{err}"
      end
      File.rename(tmp.to_s, dest.to_s)
    ensure
      FileUtils.rm_f(tmp) if tmp && tmp.exist?
    end
  end
end

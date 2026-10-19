#!/usr/bin/env ruby
# frozen_string_literal: true

# Refs: PLT-AC-44
require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")
EXPORT = ROOT.join("scripts/content/export-content-json.rb")

def fail!(message)
  warn "FAIL test-thumbnail-variants: #{message}"
  exit 1
end

def find_imagemagick
  %w[magick convert].find do |bin|
    _out, _err, status = Open3.capture3("which", bin)
    status.success?
  rescue Errno::ENOENT
    false
  end
end

magick_bin = find_imagemagick
unless magick_bin
  if ENV["CI"]
    fail!("ImageMagick is missing on CI")
  else
    puts "SKIP test-thumbnail-variants: ImageMagick not installed"
    exit 0
  end
end

def run_magick(magick_bin, *args)
  cmd = magick_bin == "magick" ? ["magick", *args] : [args.first == "identify" ? "identify" : "convert", *(args.first == "identify" ? args.drop(1) : args)]
  out, err, status = Open3.capture3(*cmd)
  fail!("ImageMagick failed (#{cmd.join(' ')}): #{out}\n#{err}") unless status.success?
  out
end

def create_image(magick_bin, path, size, color = "steelblue")
  FileUtils.mkdir_p(path.dirname)
  run_magick(magick_bin, "-size", size, "xc:#{color}", path.to_s)
end

def inject_minimal_exif!(jpeg_path)
  data = File.binread(jpeg_path)
  return unless data.start_with?("\xFF\xD8".b)

  # Minimal big-endian TIFF header with Artist tag (0x013B) = "Test"
  tiff = "MM\x00*\x00\x00\x00\x08\x00\x01\x01\x3B\x00\x02\x00\x00\x00\x05\x00\x00\x00\x1ATest\x00".b
  payload = "Exif\x00\x00".b + tiff
  app1 = "\xFF\xE1".b + [payload.bytesize + 2].pack("n") + payload
  File.binwrite(jpeg_path, data[0, 2] + app1 + data[2..])
end

def identify_info(magick_bin, path)
  raw = run_magick(magick_bin, "identify", "-format", "%w %h %m|%[EXIF:*]", path.to_s)
  dims, exif = raw.split("|", 2)
  w, h, fmt = dims.to_s.strip.split(/\s+/, 3)
  { width: w.to_i, height: h.to_i, format: fmt.to_s, exif: exif.to_s.strip }
end

def write_fixture_site(site, magick_bin)
  site.join("_config.yml").write(<<~YAML)
    title: "Test Site"
    url: "https://example.com"
    pandorga:
      identity:
        name: "Ada Example"
        url: "https://example.com"
      content:
        backend: static
      pages:
        - key: projects
          template: portfolio
          collection: projects
          path: /pages/projects/
          detail: /projects/:slug/
  YAML

  covers = site.join("content/media/images/covers")
  create_image(magick_bin, covers.join("wide.jpg"), "3000x2000", "navy")
  create_image(magick_bin, covers.join("tall.png"), "1200x1600", "darkgreen")
  create_image(magick_bin, covers.join("small.jpg"), "800x450", "darkred")
  FileUtils.mkdir_p(covers)
  covers.join("clip.mp4").write("fake video bytes")

  projects_dir = site.join("content/collections/projects")
  FileUtils.mkdir_p(projects_dir)

  entries = [
    ["wide-a", "Wide Alpha", "/media/images/covers/wide.jpg", 1],
    ["wide-b", "Wide Beta", "/media/images/covers/wide.jpg", 2],
    ["tall-p", "Tall Project", "/media/images/covers/tall.png", 3],
    ["small-p", "Small Project", "/media/images/covers/small.jpg", 4],
    ["ext-url", "External Thumbnail", "https://example.com/x.jpg", 5],
    ["video-p", "Video Thumbnail", "/media/images/covers/clip.mp4", 6],
    ["missing-p", "Missing Thumbnail", "/media/images/covers/nope.jpg", 7]
  ]

  entries.each do |key, title, thumb, order|
    projects_dir.join("#{key}.md").write(<<~MD)
      ---
      key: #{key}
      project: #{title}
      title: #{title}
      tagline: "Summary for #{title}."
      start_date: "2025-01"
      status: ongoing
      label: Ruby
      icon: terminal
      sort_order: #{order}
      thumbnail: #{thumb}
      tags:
        - Ruby
      ---

      Body for #{title}.
    MD
  end
end

begin
  require "pandorga/thumbnail_variants"
rescue LoadError => e
  fail!("cannot load pandorga/thumbnail_variants: #{e.message}")
end

# 1. Library entry point + idempotency + regeneration when original is newer.
Dir.mktmpdir("pandorga-thumb-lib-") do |dir|
  site = Pathname.new(dir)
  write_fixture_site(site, magick_bin)

  covers = site.join("content/media/images/covers")
  variants = covers.join("variants")

  summary = Pandorga::ThumbnailVariants.generate(site)
  fail!("expected generate to return a Hash, got #{summary.inspect}") unless summary.is_a?(Hash)

  # Check wide.jpg variants: 480x270, 960x540, 1440x810
  [[480, 270], [960, 540], [1440, 810]].each do |w, h|
    vpath = variants.join("wide-#{w}.jpg")
    fail!("missing #{vpath}") unless vpath.file?
    info = identify_info(magick_bin, vpath)
    fail!("wide-#{w}.jpg expected #{w}x#{h}, got #{info[:width]}x#{info[:height]}") unless info[:width] == w && info[:height] == h
    fail!("wide-#{w}.jpg expected JPEG, got #{info[:format]}") unless info[:format] == "JPEG"
    fail!("wide-#{w}.jpg expected empty EXIF, got #{info[:exif].inspect}") unless info[:exif].empty?
  end

  # Check tall.png (1200x1600): 480 and 960 exist, 1440 skipped
  [[480, 270], [960, 540]].each do |w, h|
    vpath = variants.join("tall-#{w}.jpg")
    fail!("missing #{vpath}") unless vpath.file?
    info = identify_info(magick_bin, vpath)
    fail!("tall-#{w}.jpg expected #{w}x#{h}, got #{info[:width]}x#{info[:height]}") unless info[:width] == w && info[:height] == h
    fail!("tall-#{w}.jpg expected JPEG, got #{info[:format]}") unless info[:format] == "JPEG"
    fail!("tall-#{w}.jpg expected empty EXIF, got #{info[:exif].inspect}") unless info[:exif].empty?
  end
  fail!("tall-1440.jpg must be skipped (no upscaling)") if variants.join("tall-1440.jpg").exist?

  # Check small.jpg (800x450): only 480 exists, 960 and 1440 skipped
  v480 = variants.join("small-480.jpg")
  fail!("missing #{v480}") unless v480.file?
  info480 = identify_info(magick_bin, v480)
  fail!("small-480.jpg expected 480x270, got #{info480[:width]}x#{info480[:height]}") unless info480[:width] == 480 && info480[:height] == 270
  fail!("small-480.jpg expected JPEG, got #{info480[:format]}") unless info480[:format] == "JPEG"
  fail!("small-480.jpg expected empty EXIF, got #{info480[:exif].inspect}") unless info480[:exif].empty?
  fail!("small-960.jpg must be skipped") if variants.join("small-960.jpg").exist?
  fail!("small-1440.jpg must be skipped") if variants.join("small-1440.jpg").exist?

  # Nothing written for URL, video, missing
  written_names = variants.children.map { |p| p.basename.to_s }.sort
  expected_names = %w[
    small-480.jpg
    tall-480.jpg
    tall-960.jpg
    wide-1440.jpg
    wide-480.jpg
    wide-960.jpg
  ]
  fail!("unexpected files in variants/: #{written_names.inspect}") unless written_names == expected_names

  # Check srcset_for helper
  wide_srcset = Pandorga::ThumbnailVariants.srcset_for(site, "/media/images/covers/wide.jpg")
  fail!("unexpected wide srcset: #{wide_srcset.inspect}") unless wide_srcset ==
    "/media/images/covers/variants/wide-480.jpg 480w, /media/images/covers/variants/wide-960.jpg 960w, /media/images/covers/variants/wide-1440.jpg 1440w"

  tall_srcset = Pandorga::ThumbnailVariants.srcset_for(site, "/media/images/covers/tall.png")
  fail!("unexpected tall srcset: #{tall_srcset.inspect}") unless tall_srcset ==
    "/media/images/covers/variants/tall-480.jpg 480w, /media/images/covers/variants/tall-960.jpg 960w"

  small_srcset = Pandorga::ThumbnailVariants.srcset_for(site, "/media/images/covers/small.jpg")
  fail!("unexpected small srcset: #{small_srcset.inspect}") unless small_srcset ==
    "/media/images/covers/variants/small-480.jpg 480w"

  fail!("expected nil srcset for external URL") unless Pandorga::ThumbnailVariants.srcset_for(site, "https://example.com/x.jpg").nil?
  fail!("expected nil srcset for video") unless Pandorga::ThumbnailVariants.srcset_for(site, "/media/images/covers/clip.mp4").nil?
  fail!("expected nil srcset for missing file") unless Pandorga::ThumbnailVariants.srcset_for(site, "/media/images/covers/nope.jpg").nil?

  # Idempotent rerun: set variant mtimes in the future of original, verify rerun keeps mtimes
  past = Time.now - 120
  variant_time = Time.now - 60
  [covers.join("wide.jpg"), covers.join("tall.png"), covers.join("small.jpg")].each do |orig|
    File.utime(past, past, orig.to_s)
  end
  variants.children.each { |v| File.utime(variant_time, variant_time, v.to_s) }
  mtimes_before = variants.children.to_h { |v| [v.basename.to_s, v.mtime] }

  Pandorga::ThumbnailVariants.generate(site)
  mtimes_after = variants.children.to_h { |v| [v.basename.to_s, v.mtime] }
  fail!("rerun modified up-to-date variants: #{mtimes_before.inspect} vs #{mtimes_after.inspect}") unless mtimes_before == mtimes_after

  # Touch original newer: only that image's variant set is regenerated
  newer = Time.now
  File.utime(newer, newer, covers.join("small.jpg").to_s)
  Pandorga::ThumbnailVariants.generate(site)
  fail!("expected small-480.jpg to be regenerated when small.jpg is newer") unless variants.join("small-480.jpg").mtime > mtimes_before["small-480.jpg"]
  fail!("expected wide-480.jpg mtime unchanged") unless variants.join("wide-480.jpg").mtime == mtimes_before["wide-480.jpg"]
end

# 2. CLI entry point `exe/pandorga thumbnails <root>`
Dir.mktmpdir("pandorga-thumb-cli-") do |dir|
  site = Pathname.new(dir)
  write_fixture_site(site, magick_bin)

  env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
  stdout, stderr, status = Open3.capture3(env, "ruby", EXE.to_s, "thumbnails", site.to_s)
  fail!("CLI pandorga thumbnails failed:\n#{stdout}\n#{stderr}") unless status.success?

  variants = site.join("content/media/images/covers/variants")
  %w[wide-480.jpg wide-960.jpg wide-1440.jpg tall-480.jpg tall-960.jpg small-480.jpg].each do |name|
    fail!("CLI did not write #{name}") unless variants.join(name).file?
  end
end

# 3. Full gem export runs generation itself and rewrites thumbnail_srcset URLs
Dir.mktmpdir("pandorga-thumb-export-") do |dir|
  site = Pathname.new(dir)
  write_fixture_site(site, magick_bin)
  out = site.join("_content_json")
  variants = site.join("content/media/images/covers/variants")
  fail!("variants must not exist before export") if variants.exist?

  env = {
    "RUBYOPT" => "-I#{ROOT.join('lib')}",
    "PANDORGA_SITE_ROOT" => site.to_s,
    "CONTENT_API_BASE_URL" => "https://cdn.example.com",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1"
  }
  stdout, stderr, status = Open3.capture3(
    env, "ruby", EXPORT.to_s,
    site.join("content").to_s, out.to_s,
    chdir: site.to_s
  )
  fail!("export failed:\n#{stdout}\n#{stderr}") unless status.success?
  fail!("export did not generate variants/") unless variants.join("wide-480.jpg").file?

  wide_json = JSON.parse(out.join("collections/projects/wide-a.json").read)
  wide_fm = wide_json.fetch("front_matter")
  expected_wide_srcset = [
    "https://cdn.example.com/media/images/covers/variants/wide-480.jpg 480w",
    "https://cdn.example.com/media/images/covers/variants/wide-960.jpg 960w",
    "https://cdn.example.com/media/images/covers/variants/wide-1440.jpg 1440w"
  ].join(", ")
  unless wide_fm["thumbnail"] == "https://cdn.example.com/media/images/covers/wide.jpg"
    fail!("wide-a thumbnail unexpected: #{wide_fm['thumbnail'].inspect}")
  end
  unless wide_fm["thumbnail_srcset"] == expected_wide_srcset
    fail!("wide-a thumbnail_srcset unexpected: #{wide_fm['thumbnail_srcset'].inspect}")
  end

  tall_fm = JSON.parse(out.join("collections/projects/tall-p.json").read).fetch("front_matter")
  expected_tall_srcset = [
    "https://cdn.example.com/media/images/covers/variants/tall-480.jpg 480w",
    "https://cdn.example.com/media/images/covers/variants/tall-960.jpg 960w"
  ].join(", ")
  unless tall_fm["thumbnail_srcset"] == expected_tall_srcset
    fail!("tall-p thumbnail_srcset unexpected: #{tall_fm['thumbnail_srcset'].inspect}")
  end

  small_fm = JSON.parse(out.join("collections/projects/small-p.json").read).fetch("front_matter")
  expected_small_srcset = "https://cdn.example.com/media/images/covers/variants/small-480.jpg 480w"
  unless small_fm["thumbnail_srcset"] == expected_small_srcset
    fail!("small-p thumbnail_srcset unexpected: #{small_fm['thumbnail_srcset'].inspect}")
  end

  %w[ext-url video-p missing-p].each do |slug|
    fm = JSON.parse(out.join("collections/projects/#{slug}.json").read).fetch("front_matter")
    if fm.key?("thumbnail_srcset")
      fail!("#{slug} must not have thumbnail_srcset, got #{fm['thumbnail_srcset'].inspect}")
    end
  end

  # Also check writing_index.json carries thumbnail_srcset for the home specimen
  index = JSON.parse(out.join("data/writing_index.json").read)
  wide_idx = index.find { |e| e["slug"] == "wide-a" }
  fail!("wide-a missing from writing_index.json") unless wide_idx
  unless wide_idx["thumbnail_srcset"] == expected_wide_srcset
    fail!("writing_index wide-a thumbnail_srcset unexpected: #{wide_idx['thumbnail_srcset'].inspect}")
  end
  %w[ext-url video-p missing-p].each do |slug|
    entry = index.find { |e| e["slug"] == slug }
    fail!("#{slug} missing from writing_index.json") unless entry
    if entry.key?("thumbnail_srcset")
      fail!("writing_index #{slug} must not have thumbnail_srcset, got #{entry['thumbnail_srcset'].inspect}")
    end
  end
end

# 4. Without ImageMagick: export succeeds, prints one warning line, writes no variants and no thumbnail_srcset
Dir.mktmpdir("pandorga-thumb-nomagick-") do |dir|
  site = Pathname.new(dir)
  write_fixture_site(site, magick_bin)
  out = site.join("_content_json")

  env = {
    "RUBYOPT" => "-I#{ROOT.join('lib')}",
    "PANDORGA_SITE_ROOT" => site.to_s,
    "CONTENT_API_BASE_URL" => "",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1",
    "PANDORGA_IMAGEMAGICK" => "/nonexistent/magick"
  }
  stdout, stderr, status = Open3.capture3(
    env, "ruby", EXPORT.to_s,
    site.join("content").to_s, out.to_s,
    chdir: site.to_s
  )
  fail!("export without ImageMagick failed:\n#{stdout}\n#{stderr}") unless status.success?

  combined_lines = "#{stdout}\n#{stderr}".lines.map(&:strip).reject(&:empty?)
  warnings = combined_lines.select { |l| l.match?(/warning.*imagemagick|imagemagick.*warning/i) }
  unless warnings.length == 1
    fail!("expected exactly 1 ImageMagick warning line, got #{warnings.length}: #{warnings.inspect}\nAll output:\n#{stdout}\n#{stderr}")
  end

  variants = site.join("content/media/images/covers/variants")
  if variants.exist? && variants.children.any?
    fail!("expected no variants written when ImageMagick is unavailable")
  end

  wide_fm = JSON.parse(out.join("collections/projects/wide-a.json").read).fetch("front_matter")
  if wide_fm.key?("thumbnail_srcset")
    fail!("expected no thumbnail_srcset when ImageMagick is unavailable, got #{wide_fm['thumbnail_srcset'].inspect}")
  end
end

# 5. An unreadable image warns, keeps its original, and does not stop the export.
Dir.mktmpdir("pandorga-thumb-corrupt-") do |dir|
  site = Pathname.new(dir)
  write_fixture_site(site, magick_bin)
  site.join("content/media/images/covers/small.jpg").write("not a jpeg")
  out = site.join("_content_json")
  env = {
    "RUBYOPT" => "-I#{ROOT.join('lib')}",
    "PANDORGA_SITE_ROOT" => site.to_s,
    "CONTENT_API_BASE_URL" => "",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1"
  }
  stdout, stderr, status = Open3.capture3(
    env, "ruby", EXPORT.to_s,
    site.join("content").to_s, out.to_s,
    chdir: site.to_s
  )
  fail!("export with an unreadable image failed:\n#{stdout}\n#{stderr}") unless status.success?
  fail!("expected a warning naming small.jpg") unless "#{stdout}\n#{stderr}".match?(/warning.*small\.jpg/)
  variants = site.join("content/media/images/covers/variants")
  fail!("unreadable image must not get variants") if variants.join("small-480.jpg").exist?
  fail!("readable images must still get variants") unless variants.join("wide-480.jpg").file?
  small_fm = JSON.parse(out.join("collections/projects/small-p.json").read).fetch("front_matter")
  fail!("unreadable image must not get thumbnail_srcset") if small_fm.key?("thumbnail_srcset")
end

puts "PASS test-thumbnail-variants"

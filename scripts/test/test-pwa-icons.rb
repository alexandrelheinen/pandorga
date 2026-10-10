#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-28. The site and Studio launchers share the site stamp. Studio adds
# one badge. Manifests name maskable icons, and those icons keep their art
# inside the center 80% circle.

require "jekyll"
require "json"
require "pathname"
require "tmpdir"
require "zlib"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-pwa-icons: #{message}"
  exit 1
end

PLATE = [0x5e, 0x5d, 0x59].freeze
BADGE = [0xb8, 0xb7, 0xae].freeze
PRIMARY = [0xa4, 0xc8, 0xda].freeze

def read_png(path)
  data = File.binread(path)
  fail!("#{path} is not a PNG") unless data.start_with?("\x89PNG\r\n\x1a\n".b)

  pos = 8
  width = height = nil
  idat = +"".b
  while pos + 12 <= data.bytesize
    length = data[pos, 4].unpack1("N")
    type = data[pos + 4, 4]
    chunk = data[pos + 8, length]
    pos += 12 + length
    case type
    when "IHDR"
      width, height, bit, color, _comp, _filter, interlace = chunk.unpack("NNCCCCC")
      fail!("#{path} is not 8-bit RGB") unless bit == 8 && color == 2 && interlace == 0
    when "IDAT"
      idat << chunk
    when "IEND"
      break
    end
  end
  fail!("#{path} has no image") unless width && height && !idat.empty?

  raw = Zlib::Inflate.inflate(idat)
  stride = width * 3
  row_start = 0
  prev = Array.new(stride, 0)
  pixels = []
  height.times do
    filter = raw.getbyte(row_start)
    row = raw.byteslice(row_start + 1, stride).bytes
    row_start += stride + 1
    out = Array.new(stride, 0)
    stride.times do |i|
      left = i >= 3 ? out[i - 3] : 0
      up = prev[i]
      up_left = i >= 3 ? prev[i - 3] : 0
      value = row[i]
      out[i] = case filter
               when 0 then value
               when 1 then (value + left) & 255
               when 2 then (value + up) & 255
               when 3 then (value + ((left + up) / 2)) & 255
               when 4
                 estimate = left + up - up_left
                 nearest = [[estimate - left, left], [estimate - up, up], [estimate - up_left, up_left]]
                 nearest.map! { |distance, sample| [distance.abs, sample] }
                 (value + nearest.min_by(&:first).last) & 255
               else
                 fail!("#{path} uses PNG filter #{filter}")
               end
    end
    prev = out
    width.times { |x| pixels << out[x * 3, 3] }
  end
  [width, height, pixels]
end

def pixel(image, x, y)
  width, _height, pixels = image
  pixels[(y * width) + x]
end

def assert_margin(path, image)
  width, height, = image
  band = (width * 0.10).floor
  samples = [
    [0, 0],
    [width - 1, 0],
    [0, height - 1],
    [width - 1, height - 1],
    [band - 1, height / 2],
    [width - band, height / 2],
    [width / 2, band - 1],
    [width / 2, height - band]
  ]
  samples.each do |x, y|
    got = pixel(image, x, y)
    fail!("#{path} pixel #{x},#{y} is #{got.inspect}, outside the safe zone") unless got == PLATE
  end
end

logo = ROOT.join("_includes/theme/site-logo.html").read
site_svg = ROOT.join("assets/icons/favicon.svg").read
studio_svg = ROOT.join("assets/icons/studio-logo.svg").read
%w[0,0 23,0 15,17 0,20 23,0 32,0 32,32 17,21 15,17 0,20 15,17 17,21 32,32 0,32].each do |point|
  fail!("site stamp lost the point #{point}") unless logo.include?(point) && site_svg.include?(point) && studio_svg.include?(point)
end
fail!("Studio icon is still the hexagon") if studio_svg.include?("16,1") || studio_svg.include?("30,9")
fail!("site icon carries the Studio badge") if site_svg.include?("badge")
fail!("Studio icon has no badge") unless studio_svg.include?('class="badge"') && studio_svg.include?('x="20.32"')
fail!("favicon names the owner") if site_svg.match?(/Heinen|Alexandre/i)

shell = ROOT.join("_includes/theme/favicons.html").read
fail!("shell does not link the site manifest") unless shell.include?('href="/site.webmanifest"')
studio = ROOT.join("studio/index.html").read
studio_app = ROOT.join("studio-app/index.html").read
[studio, studio_app].each do |html|
  fail!("Studio does not link its manifest") unless html.include?('href="/studio.webmanifest"')
  fail!("Studio apple touch icon is the 32px file") if html.include?('apple-touch-icon" href="/assets/icons/studio-logo-32.png"')
  fail!("Studio apple touch icon is missing") unless html.include?("/assets/icons/studio-apple-touch-icon.png")
end

def build_manifests(config_yaml)
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "_config.yml"), config_yaml)
    File.write(File.join(dir, "index.html"), "hello\n")
    config = Jekyll.configuration(
      "source" => dir,
      "destination" => File.join(dir, "_site"),
      "quiet" => true,
      "safe" => false
    )
    site = Jekyll::Site.new(config)
    site.reset
    site.read
    Pandorga::Jekyll::WebManifestGenerator.new.generate(site)
    site.pages.select { |page| page.name.end_with?(".webmanifest") }.to_h do |page|
      fail!("#{page.name} would enter the sitemap") unless page.data["sitemap"] == false
      [page.name, JSON.parse(page.content)]
    end
  end
end

require_relative "../../lib/pandorga/jekyll/plugins/web_manifest"

named = build_manifests(<<~YAML)
  title: Fallback Title
  pandorga:
    identity:
      name: Example Person
      short_name: Example
YAML
site = named["site.webmanifest"]
studio_manifest = named["studio.webmanifest"]
fail!("manifests were not written") unless site && studio_manifest
fail!("site name ignored identity") unless site["name"] == "Example Person" && site["short_name"] == "Example"
fail!("site scope is not the origin root") unless site["id"] == "/" && site["scope"] == "/" && site["start_url"] == "/"
fail!("Studio is not its own app") unless studio_manifest["id"] == "/studio/" && studio_manifest["scope"] == "/studio/"
fail!("Studio name changed") unless studio_manifest["name"] == "Studio" && studio_manifest["start_url"] == "/studio/"
fail!("launcher plate changed") unless site["background_color"] == "#5e5d59" && site["theme_color"] == "#5e5d59"

{
  "site.webmanifest" => [
    ["/assets/icons/icon-512.png", "512x512", "any"],
    ["/assets/icons/icon-maskable-512.png", "512x512", "maskable"],
    ["/assets/icons/icon-192.png", "192x192", "any"],
    ["/assets/icons/icon-maskable-192.png", "192x192", "maskable"]
  ],
  "studio.webmanifest" => [
    ["/assets/icons/studio-icon-512.png", "512x512", "any"],
    ["/assets/icons/studio-maskable-512.png", "512x512", "maskable"],
    ["/assets/icons/studio-icon-192.png", "192x192", "any"],
    ["/assets/icons/studio-maskable-192.png", "192x192", "maskable"]
  ]
}.each do |name, expected|
  got = named.fetch(name).fetch("icons").map { |icon| [icon["src"], icon["sizes"], icon["purpose"]] }
  fail!("#{name} icons are #{got.inspect}") unless got == expected
end

fallback = build_manifests("title: \"\"\n")
fail!("empty identity must still name the app") unless fallback["site.webmanifest"]["name"] == "Site"

{
  "assets/icons/favicon.ico" => nil,
  "assets/icons/favicon-32.png" => 32,
  "assets/icons/apple-touch-icon.png" => 180,
  "assets/icons/icon-512.png" => 512,
  "assets/icons/icon-192.png" => 192,
  "assets/icons/studio-apple-touch-icon.png" => 180,
  "assets/icons/studio-icon-512.png" => 512,
  "assets/icons/studio-icon-192.png" => 192,
  "assets/icons/studio-logo-32.png" => 32
}.each do |rel, size|
  path = ROOT.join(rel)
  fail!("missing #{rel}") unless path.file?
  next unless size

  image = read_png(path)
  fail!("#{rel} is #{image[0]}x#{image[1]}") unless image[0] == size && image[1] == size
end

[512, 192].each do |size|
  site_path = ROOT.join("assets/icons/icon-maskable-#{size}.png")
  studio_path = ROOT.join("assets/icons/studio-maskable-#{size}.png")
  site_image = read_png(site_path)
  studio_image = read_png(studio_path)
  fail!("site maskable is #{site_image[0]} square") unless site_image[0] == size && site_image[1] == size
  fail!("Studio maskable is #{studio_image[0]} square") unless studio_image[0] == size && studio_image[1] == size
  assert_margin(site_path, site_image)
  assert_margin(studio_path, studio_image)

  mark = (size * 0.24).round + (2.0 / 32 * size * 0.52).round
  fail!("site stamp is not the pastel triad") unless pixel(site_image, mark, mark) == PRIMARY
  fail!("Studio stamp is not the pastel triad") unless pixel(studio_image, mark, mark) == PRIMARY

  badge_at = (size * 0.68).round
  fail!("site icon has the Studio badge") if pixel(site_image, badge_at, badge_at) == BADGE
  fail!("Studio badge is missing") unless pixel(studio_image, badge_at, badge_at) == BADGE

  differ = site_image[2].zip(studio_image[2]).count { |left, right| left != right }
  fail!("Studio icon is a different picture (#{differ} pixels)") unless differ.positive? && differ < (size * size * 0.03)
end

puts "PASS test-pwa-icons"

#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-51. A 16:9 home hero at every width (docs/features/hero-16x9.md).
#
# Each check names the acceptance item it covers (51.1 … 51.10). Pass item
# numbers to run a subset: `ruby scripts/test/test-hero-16x9.rb 4 5`.
# 51.9 writes images with ImageMagick. Without it the generator half is
# skipped locally and fails on CI, like test-thumbnail-variants.

require "fileutils"
require "open3"
require "pathname"
require "set"
require "tmpdir"
require "yaml"

ROOT = Pathname.new(__dir__).join("../..").expand_path
HOME_CSS = ROOT.join("assets/css/ledger/home.css")
LAYOUT = ROOT.join("_layouts/home.html")
SHELL = ROOT.join("_layouts/shell.html")
RUNTIME = ROOT.join("_includes/content-runtime/60-fragments.html")
SCHEMA = ROOT.join("lib/pandorga/registry/schema.yml")
CONFIG_DOC = ROOT.join("docs/configuration.md")

require_relative "../content/hero_portraits"
require_relative "../../lib/pandorga/thumbnail_variants"

ONLY_ITEMS = ARGV.map { |a| a.sub(/\A(PLT-AC-)?51\./, "") }.to_set
DESKTOP = "(min-width:1024px)"
PHONE = "(max-width:767px)"
STACK = "(max-width:1023px)" # CR-22 full-bleed photo-bg

$failures = []

def item(id)
  return if !ONLY_ITEMS.empty? && !ONLY_ITEMS.include?(id.to_s)

  @item = id
  yield
end

def fail!(msg)
  $failures << "FAIL PLT-AC-51.#{@item}: #{msg}"
end

# ── CSS parser (same shape as test-v3-layout.rb) ───────────────────────────

def strip_comments(text)
  text.gsub(%r{/\*.*?\*/}m, "")
end

def split_top(text, sep)
  parts = []
  depth = 0
  buf = +""
  text.each_char do |c|
    if c == "(" || c == "["
      depth += 1
    elsif c == ")" || c == "]"
      depth -= 1
    elsif c == sep && depth.zero?
      parts << buf
      buf = +""
      next
    end
    buf << c
  end
  parts << buf
  parts.map(&:strip).reject(&:empty?)
end

def parse_rules(css, media = nil, out = [])
  i = 0
  head = +""
  while i < css.length
    c = css[i]
    if c == "{"
      depth = 1
      j = i + 1
      while j < css.length && depth.positive?
        depth += 1 if css[j] == "{"
        depth -= 1 if css[j] == "}"
        j += 1
      end
      body = css[(i + 1)...(j - 1)]
      h = head.strip
      if h.start_with?("@media")
        inner = h.sub(/\A@media/, "").gsub(/\s+/, "")
        parse_rules(body, [media, inner].compact.join("and"), out)
      elsif h.start_with?("@supports", "@layer", "@container")
        parse_rules(body, media, out)
      elsif !h.start_with?("@")
        decls = split_top(body, ";").filter_map do |d|
          prop, val = d.split(":", 2)
          next unless val

          [prop.strip.downcase, val.gsub(/\s+/, " ").strip]
        end
        split_top(h, ",").each do |sel|
          out << { sel: sel.gsub(/\s+/, " ").strip, decls: decls, media: media, order: out.length }
        end
      end
      head = +""
      i = j
    elsif c == ";" && head.strip.start_with?("@")
      head = +""
      i += 1
    elsif c == "}"
      i += 1
    else
      head << c
      i += 1
    end
  end
  out
end

RULES = parse_rules(strip_comments(HOME_CSS.read))

def rules_for(sel, media: :any)
  RULES.select do |r|
    r[:sel] == sel && (media == :any || r[:media] == media)
  end
end

# The value the last matching rule declares, or nil.
def decl(sel, prop, media: nil)
  rules_for(sel, media: media).reverse_each do |r|
    pair = r[:decls].reverse.find { |p, _| p == prop }
    return pair[1] if pair
  end
  nil
end

def expect_decl(sel, prop, want, media: nil)
  got = decl(sel, prop, media: media)
  # CR-22 overrides use !important; compare the declared value without the flag.
  bare = got.to_s.sub(/\s*!important\z/, "").strip
  ok = want.is_a?(Regexp) ? bare.match?(want) : bare == want
  where = media ? " under #{media}" : ""
  fail!("#{sel} #{prop} should be #{want.inspect}#{where}, got #{got.inspect}") unless ok
end

def hero_rule?(r)
  r[:sel].include?("home-hero")
end

# ── 51.1 Plate ──────────────────────────────────────────────────────────────

item(1) do
  expect_decl(".home-hero-plate", "aspect-ratio", "16 / 9")
  RULES.select { |r| hero_rule?(r) }.each do |r|
    r[:decls].each do |prop, val|
      next unless prop == "aspect-ratio"

      if val.match?(%r{\A(3\s*/\s*4|4\s*/\s*3)\z})
        fail!("#{r[:sel]} sets aspect-ratio #{val} under #{r[:media].inspect}")
      end
    end
  end
  landscape = RULES.select { |r| r[:sel].include?("--landscape") && hero_rule?(r) }
  fail!("no .home-hero-plate--landscape rule may remain") unless landscape.empty?
end

# ── 51.2 Stacked full-bleed (CR-22, <1024) ─────────────────────────────────

item(2) do
  expect_decl(".home-band--hero", "width", "100vw", media: STACK)
  expect_decl(".home-hero-portrait", "position", "absolute", media: STACK)
  expect_decl(".home-hero-plate", "aspect-ratio", "auto", media: STACK)
  expect_decl(".home-hero-plate img", "object-position", /\Acenter( center)?\z/, media: STACK)
end

# ── 51.3 Portrait must not be width-capped ─────────────────────────────────

item(3) do
  rules_for(".home-hero-portrait").each do |r|
    r[:decls].each do |prop, val|
      next unless prop == "max-width" && val.match?(/rem/)

      fail!(".home-hero-portrait max-width #{val} under #{r[:media].inspect} caps the plate")
    end
  end
end

# ── 51.4 From 1024px — photo as background (CR-22 / PLT-AC-82) ─────────────

item(4) do
  expect_decl(".home-hero", "display", "flex", media: DESKTOP)
  expect_decl(".home-hero-portrait", "position", "absolute", media: DESKTOP)
  expect_decl(".home-hero-portrait", "aspect-ratio", "auto", media: DESKTOP)
  [".home-hero-plate-wrap", ".home-hero-plate"].each do |sel|
    expect_decl(sel, "position", "absolute", media: DESKTOP)
    expect_decl(sel, "inset", "0", media: DESKTOP)
    expect_decl(sel, "aspect-ratio", "auto", media: DESKTOP)
  end
  expect_decl(".home-hero-plate img", "object-fit", "cover", media: DESKTOP)
  expect_decl(".home-hero-plate img", "object-position", /\Acenter( center)?\z/, media: DESKTOP)
  expect_decl(".home-hero-actions", "flex-wrap", "nowrap", media: DESKTOP)

  layout = LAYOUT.read
  fail!("the crosshairs must stay on the plate wrapper") unless layout.include?('class="ledger-frame-crosshairs"')
  fail!("the corner marks must stay in the plate") unless layout.include?('class="ledger-frame-corners"')
end

# ── 51.5 Cascade ────────────────────────────────────────────────────────────

item(5) do
  [".home-hero-portrait", ".home-hero-plate-wrap", ".home-hero-plate", ".home-hero-plate img"].each do |sel|
    base = rules_for(sel, media: nil).map { |r| r[:order] }.max
    wide = rules_for(sel, media: DESKTOP).map { |r| r[:order] }.min
    if base.nil? || wide.nil?
      fail!("#{sel} needs a base rule and a #{DESKTOP} rule")
    elsif wide < base
      fail!("the #{DESKTOP} #{sel} rule comes before its base rule, which wins on source order")
    end
  end
end

# ── 51.6 Name from 1024px ───────────────────────────────────────────────────

item(6) do
  # CR-22.1: B3 desk name clamp (also declared on .home-hero-title)
  title = ".home-hero-title"
  expect_decl(title, "white-space", "nowrap", media: DESKTOP)
  expect_decl(title, "font-size",
              "calc(clamp(1.85rem, 2.6vw, 2.55rem) + 2pt)",
              media: DESKTOP)
end

# ── 51.7 Markup ─────────────────────────────────────────────────────────────

item(7) do
  layout = LAYOUT.read
  imgs = layout.scan(/<img[^>]*data-content-hero-portrait[^>]*>/m)
  fail!("the layout must render exactly one hero image, got #{imgs.length}") unless imgs.length == 1
  img = imgs.first.to_s
  unless img.include?('width="1600"') && img.include?('height="900"')
    fail!("the hero image must be 1600×900, got #{img.inspect}")
  end
  fail!("no data-hero-landscape on the hero image") if img.include?("data-hero-landscape")
  hero = layout[/<div class="home-hero-portrait">.*?<\/figure>/m].to_s
  fail!("the plate has no <picture> or <source>") if hero.include?("<picture") || hero.include?("<source")
  fail!("the home layout must not read hero_landscape") if layout.include?("hero_landscape")
  fail!("the plate has no --landscape class") if layout.include?("home-hero-plate--landscape")
  shell = SHELL.read
  fail!("the shell must not read hero_landscape") if shell.include?("hero_landscape")
  fail!("the shell must not preload a hero image") if shell.match?(/rel="preload" as="image"/)
end

# ── 51.8 Runtime ────────────────────────────────────────────────────────────

item(8) do
  runtime = RUNTIME.read
  start = runtime.index("function heroPortraitEntries")
  finish = runtime.index("function hydratePageFragments")
  if start.nil? || finish.nil? || finish < start
    fail!("hero functions must precede hydratePageFragments")
  else
    body = runtime[start...finish]
    %w[heroLandscapeEntries paintNarrowHero showConfiguredLandscape showHeroLandscape
       applyHeroLandscapeFile setNarrowSource watchHeroFrame configuredLandscape heroPlate].each do |name|
      fail!("#{name} must be removed") if body.include?(name)
    end
    fail!("the hero draw must not watch a media query") if body.include?("matchMedia")
    fail!("the hero runtime must not read a landscape field") if body.include?("landscape")
    hydrate = body[/function hydrateHeroPortrait\(\) \{.*?\n    \}/m].to_s
    unless hydrate.include?("loadJson('pages/home/portraits.json')") && hydrate.include?("showHeroPortrait(img, heroPortraitEntries(data))")
      fail!("hydrateHeroPortrait must draw from portraits.json at every width, got #{hydrate.inspect}")
    end
  end
end

# ── 51.9 Export ─────────────────────────────────────────────────────────────

# Minimal JPEG and PNG headers. HeroPortraits reads only the size.
def write_jpeg_header(path, width, height)
  sof = [0xFF, 0xC0, 0x00, 0x11, 0x08].pack("C*") + [height, width].pack("nn") +
        [0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01].pack("C*")
  app0 = [0xFF, 0xE0, 0x00, 0x10].pack("C*") + "JFIF\x00".b + [1, 1, 0, 0, 1, 0, 1, 0, 0].pack("C*")
  FileUtils.mkdir_p(path.dirname)
  File.binwrite(path, [0xFF, 0xD8].pack("C*") + app0 + sof + [0xFF, 0xD9].pack("C*"))
end

def write_png_header(path, width, height)
  ihdr = "IHDR".b + [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC")
  FileUtils.mkdir_p(path.dirname)
  File.binwrite(path, "\x89PNG\r\n\x1A\n".b + [13].pack("N") + ihdr + "\x00\x00\x00\x00".b)
end

item(9) do
  Dir.mktmpdir("hero-16x9") do |dir|
    root = Pathname.new(dir)
    pool = root.join("media/images/hero")
    write_jpeg_header(pool.join("a.jpg"), 1920, 1080)
    write_jpeg_header(pool.join("variants/a-480.jpg"), 480, 270)
    write_jpeg_header(pool.join("variants/a-960.jpg"), 960, 1280) # stale 3:4
    write_png_header(pool.join("b.png"), 1920, 1080)
    write_png_header(pool.join("variants/b-1440.jpg"), 1440, 810) # sniffed, not by name

    got = HeroPortraits.entries(root)
    sizes = "(max-width: 1023px) 100vw, 50vw"
    want = [
      { "src" => "/media/images/hero/a.jpg",
        "srcset" => "/media/images/hero/variants/a-480.jpg 480w", "sizes" => sizes },
      { "src" => "/media/images/hero/b.png",
        "srcset" => "/media/images/hero/variants/b-1440.jpg 1440w", "sizes" => sizes }
    ]
    fail!("entries must list only 16:9 variants, got #{got.inspect}") unless got == want
    fail!("no entry may carry landscape") if got.any? { |e| e.key?("landscape") }
  end

  bins = Pandorga::ThumbnailVariants.resolve_imagemagick
  if bins.nil?
    if ENV["CI"]
      fail!("ImageMagick is missing on CI")
    else
      puts "SKIP PLT-AC-51.9 generator: ImageMagick not installed"
    end
    next
  end

  Dir.mktmpdir("hero-16x9-gen") do |dir|
    root = Pathname.new(dir)
    pool = root.join("content/media/images/hero")
    FileUtils.mkdir_p(pool)
    big = pool.join("wide.jpg")
    small = pool.join("small.jpg")
    out, status = Open3.capture2e(*bins[:convert], "-size", "1920x1080", "xc:steelblue", big.to_s)
    fail!("could not draw a fixture: #{out}") unless status.success?
    out, status = Open3.capture2e(*bins[:convert], "-size", "1000x750", "xc:tomato", small.to_s)
    fail!("could not draw a fixture: #{out}") unless status.success?
    stale = pool.join("variants/wide-960.jpg")
    FileUtils.mkdir_p(stale.dirname)
    out, status = Open3.capture2e(*bins[:convert], "-size", "960x1280", "xc:gray", stale.to_s)
    fail!("could not draw a fixture: #{out}") unless status.success?
    past = Time.now - 3600
    File.utime(past, past, big.to_s)
    File.utime(past, past, small.to_s)

    Pandorga::ThumbnailVariants.generate(root)

    size_of = lambda do |path|
      o, _e, s = Open3.capture3(*bins[:identify], "-format", "%wx%h", "#{path}[0]")
      s.success? ? o.strip : nil
    end
    { "wide-480.jpg" => "480x270", "wide-960.jpg" => "960x540", "wide-1440.jpg" => "1440x810",
      "small-480.jpg" => "480x270", "small-960.jpg" => "960x540" }.each do |name, want|
      got = size_of.call(pool.join("variants", name))
      fail!("variants/#{name} should be #{want}, got #{got.inspect}") unless got == want
    end
    fail!("no variant wider than its original") if pool.join("variants/small-1440.jpg").exist?

    entries = HeroPortraits.entries(root.join("content"))
    wide = entries.find { |e| e["src"] == "/media/images/hero/wide.jpg" }
    want = %w[480 960 1440].map { |w| "/media/images/hero/variants/wide-#{w}.jpg #{w}w" }.join(", ")
    fail!("the export must list the generated variants, got #{wide.inspect}") unless wide && wide["srcset"] == want
  end
end

# ── 51.10 Registry ──────────────────────────────────────────────────────────

item(10) do
  schema = YAML.safe_load(SCHEMA.read, aliases: true) || {}
  keys = schema.dig("home", "keys") || {}
  fail!("pandorga.home.hero_landscape must leave the registry schema") if keys.key?("hero_landscape")
  fail!("docs/configuration.md must not list hero_landscape") if CONFIG_DOC.read.include?("hero_landscape")
end

if $failures.empty?
  puts "PLT-AC-51: all checks passed"
else
  puts $failures
  exit 1
end

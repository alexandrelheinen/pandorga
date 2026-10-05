#!/usr/bin/env ruby
# frozen_string_literal: true

# Home band art (docs/features/home-band-art.md).
#
# AC-BAND-01 the export writes both plates under data/
# AC-BAND-03 a second export with no content change reports them unchanged
# AC-BAND-07 the layout carries no generated SVG markup
# AC-BAND-08 the network plate prints the counts computed from the same corpus
# AC-BAND-09 an entry joined to nothing leaves the plate's bar short of full width

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

require_relative "../content/band_art"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT = ROOT.join("scripts/content/export-content-json.rb")
LAYOUT = ROOT.join("_layouts/home.html")
INDEX_BAND = ROOT.join("_includes/home/band-index.html")
EXAMPLE_CONTENT = ROOT.join("examples/full/content")

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

puts "Testing home band art..."

# ── The drawing, against a corpus small enough to count by hand ────────────

index = [
  { "key" => "a", "url" => "/articles/a/", "collection" => "articles", "date" => "2026-01-01",
    "tags" => %w[Engineering Writing], "xcites" => [] },
  { "key" => "b", "url" => "/articles/b/", "collection" => "articles", "date" => "2026-02-01",
    "tags" => ["Engineering"], "xcites" => ["a"] },
  { "key" => "c", "url" => "/posts/c/", "collection" => "posts", "date" => "2026-03-01",
    "tags" => ["Writing"], "xcites" => %w[a a b] },
  # Joined to nothing, so it is counted in the corpus and drawn nowhere.
  { "key" => "d", "url" => "/posts/d/", "collection" => "posts", "date" => "2026-04-01",
    "tags" => ["Solitude"], "xcites" => [] },
  # Not writing: the plate's legend never names projects.
  { "key" => "e", "url" => "/projects/e/", "collection" => "projects", "date" => "2026-05-01",
    "tags" => ["Engineering"], "xcites" => ["a"] }
]

graph = BandArt.idea_graph(index)
check! graph[:nodes].map { |node| node["key"] } == %w[a b c],
       "unjoined and non-writing entries must stay out of the graph, got #{graph[:nodes].map { |n| n['key'] }}"
check! graph[:corpus] == 4, "corpus counts every keyed article and post, got #{graph[:corpus]}"
check! graph[:edges].length == 3, "c cites a twice and it counts once, got #{graph[:edges].length}"
check! graph[:themes].map { |theme| theme[:name] } .sort == %w[Engineering Writing],
       "a tag used once is not a theme, got #{graph[:themes].map { |t| t[:name] }}"

resources = [
  { "slug" => "one", "category" => "Academic", "type" => "youtube" },
  { "slug" => "two", "category" => "Academic", "type" => "podcast" },
  { "slug" => "three", "category" => "Music", "type" => "website" }
]

plates = BandArt.build(writing_index: index, resources: resources)
check! plates.keys.sort == %w[network sources], "build draws both plates, got #{plates.keys}"

# AC-BAND-08: the numbers are counted, not typed. The three numerals are the
# drawing, so they are read out of the markup rather than out of a caption.
network = plates["network"]
numerals = network.scan(%r{class="home-index-metric"[^>]*>(\d+)<}).flatten
check! numerals == %w[3 3 2], "the metric card must print the computed graph, got #{numerals.inspect}"
check! network.include?(%(data-band-tally="3 of 4 pieces joined")),
       "the caption must say how much of the corpus is joined, got #{network[%r{data-band-tally="[^"]*"}]}"
check! network.include?(%(home-index-spine--articles" x="10" y="96" width="150")) &&
       network.include?(%(home-index-spine--posts" x="160" y="96" width="75")),
       "the spine scales to the corpus and stops short of the margin when a piece is unjoined, "        "got #{network.scan(%r{home-index-spine--\w+" x="[^"]*" y="[^"]*" width="[^"]*"})}"
check! plates["sources"].include?('data-band-tally="3 sources · 2 collections"'),
       "sources tally must restate the shelf, got #{plates['sources'][/data-band-tally="[^"]*"/]}"
check! plates["sources"].include?(">Acad.<") && plates["sources"].include?(">Music<"),
       "shelf labels must use the short forms, got #{plates['sources'].scan(%r{home-index-collection[^>]*>([^<]+)})}"

# Nothing may be drawn in a colour the palette cannot repaint.
plates.each do |name, svg|
  check! !svg.match?(/#[0-9a-fA-F]{3,8}\b/), "#{name} plate carries a literal colour"
  check! svg.start_with?("<svg "), "#{name} plate must be a standalone SVG document"
  check! svg.include?('xmlns="http://www.w3.org/2000/svg"'), "#{name} plate needs the SVG namespace"
end

# AC-BAND-07: the layout may not hold generated markup any more.
layout = LAYOUT.read
check! !layout.include?("<svg"), "_layouts/home.html must not carry generated SVG"
index_band = INDEX_BAND.read
check! index_band.include?('data-content-band-art="sources"') ||
         index_band.include?('data-content-band-art="{{ _art_key }}"'),
       "the sources panel needs its mount point"
check! index_band.include?("data-content-band-art"),
       "the network panel needs its mount point"

# ── The export, end to end ────────────────────────────────────────────────

Dir.mktmpdir("band-art") do |dir|
  out = Pathname.new(dir).join("export")
  content_root = EXAMPLE_CONTENT.directory? ? EXAMPLE_CONTENT : ROOT.join("content")
  env = {
    "CONTENT_API_BASE_URL" => "",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1",
    "PANDORGA_SITE_ROOT" => (EXAMPLE_CONTENT.directory? ? ROOT.join("examples/full") : ROOT).to_s,
    "RUBYOPT" => "-I#{ROOT.join('lib')}"
  }
  command = ["ruby", EXPORT.to_s, content_root.to_s, out.to_s]

  first, status = Open3.capture2e(env, *command, chdir: env["PANDORGA_SITE_ROOT"])
  check! status.success?, "first export failed:\n#{first}"

  # AC-BAND-01
  %w[band-art-sources.svg band-art-network.svg].each do |name|
    path = out.join("data", name)
    check! path.file?, "the export must write data/#{name}"
    check! path.read.start_with?("<svg "), "data/#{name} must be an SVG document"
  end

  manifest = JSON.parse(out.join("manifest.json").read)
  check! manifest["files"]["band_art"].sort == ["data/band-art-network.svg", "data/band-art-sources.svg"],
         "the manifest must list both plates, got #{manifest['files']['band_art'].inspect}"

  before = out.join("data", "band-art-sources.svg").read

  # AC-BAND-03: a re-export must reuse the bytes, or every run churns R2.
  second, status = Open3.capture2e(env, *command, chdir: env["PANDORGA_SITE_ROOT"])
  check! status.success?, "second export failed:\n#{second}"
  check! out.join("data", "band-art-sources.svg").read == before,
         "a re-export with no content change rewrote the sources plate"
  check! second.include?("band_art: 2"), "the export must report both plates:\n#{second}"
end

puts "Home band art OK."

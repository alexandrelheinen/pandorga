#!/usr/bin/env ruby
# frozen_string_literal: true

# Home hero portraits (docs/features/hero-portraits.md).
#
# AC-HERO-01 the pool directory and the list agree
# AC-HERO-02 the export writes pages/home/portraits.json
# AC-HERO-03 Studio does not register an editorial list
# AC-HERO-04 the plate starts with no photograph
# AC-HERO-05 the runtime draws once per load and fades the file in after it loads
# AC-HERO-06 / AC-HERO-07 the picker, executed from the runtime source

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"
require "date"

require_relative "../content/hero_portraits"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT = ROOT.join("scripts/content/export-content-json.rb")
LAYOUT = ROOT.join("_layouts/home.html")
SHELL = ROOT.join("_layouts/shell.html")
HOME_CSS = ROOT.join("assets/css/ledger/home.css")
RUNTIME = ROOT.join("_includes/content-runtime/60-fragments.html")
SCHEMA = ROOT.join("studio/schema.yml")
PICKER = ROOT.join("scripts/test/test-hero-portraits.mjs")
POOL = ROOT.join("content/media/images/hero")

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

puts "Testing home hero portraits..."

# ── AC-HERO-01 ──────────────────────────────────────────────────────────────

check!(!ROOT.join("content/pages/home/portraits.yml").exist?,
       "the author does not keep a portrait list")

# The four photographs live with the site, not in the gem. When they are
# here, the folder must be exactly that set. When they are not, the picker
# extracted from the runtime still has to run.
personal_pool = %w[DSC00571.JPG DSC00632.JPG DSC00721.JPG DSC00727.JPG]
pool_names = POOL.directory? ? POOL.children.select(&:file?).map { |path| path.basename.to_s }.sort : []
if pool_names.empty?
  puts "AC-HERO-01: no hero photographs in this checkout"
elsif pool_names != personal_pool
  check!(false, "the hero folder must hold the four uploaded photographs, got #{pool_names.inspect}")
end

Dir.mktmpdir("hero-pool") do |dir|
  root = Pathname.new(dir)
  pool = root.join("media/images/hero")
  pool.mkpath
  FileUtils.touch(pool.join("b.JPG"))
  FileUtils.touch(pool.join("a.png"))
  FileUtils.touch(pool.join("note.txt"))

  got = HeroPortraits.entries(root)
  check!(got == [
           { "src" => "/media/images/hero/a.png" },
           { "src" => "/media/images/hero/b.JPG" }
         ],
         "the folder is the pool and non-images stay out, got #{got.inspect}")
end

# ── AC-HERO-03 ──────────────────────────────────────────────────────────────

schema = YAML.safe_load(SCHEMA.read, permitted_classes: [Date, Time], aliases: true) || {}

def each_content_entry(nodes, &block)
  Array(nodes).each do |entry|
    next unless entry.is_a?(Hash)

    if entry["type"].to_s == "group"
      each_content_entry(entry["items"], &block)
    else
      yield entry
    end
  end
end

registered = nil
each_content_entry(schema["content"]) do |entry|
  registered = entry if entry["path"].to_s == "content/pages/home/portraits.yml"
end
check!(registered.nil?, "studio/schema.yml must not register a portrait list")

# ── AC-HERO-04 and AC-HERO-05 (source shape) ───────────────────────────────

layout = LAYOUT.read
check!(!layout.include?("profile-monologue"),
       "the deleted shell photograph must not be referenced")
check!(!ROOT.join("assets/images/profile-monologue.JPG").exist?,
       "profile-monologue.JPG must not exist")
hero_imgs = layout.scan(/<img[^>]*data-content-hero-portrait[^>]*>/m)
check!(hero_imgs.any?, "the plate image is missing")
hero_imgs.each do |hero_img|
  check!(!hero_img.include?("src=") && hero_img.include?('alt=""'),
         "the plate starts without a photographic src and keeps an empty alt, got #{hero_img.inspect}")
  check!(hero_img.include?('fetchpriority="high"'),
         "the hero image must request fetchpriority high, got #{hero_img.inspect}")
end
check!(layout.include?("page.hero_landscape") && layout.include?("site.pandorga.home.hero_landscape"),
       "narrow hero reads front matter and pandorga.home.hero_landscape")
check!(layout.include?('media="(max-width: 767px)"') && layout.include?("<picture>"),
       "a configured landscape file is a picture source for narrow viewports")
check!(layout.include?("data-hero-landscape"),
       "the image carries the landscape URL for the runtime")
shell = SHELL.read
check!(shell.include?('rel="preload" as="image"') && shell.include?('fetchpriority="high"') &&
         shell.include?('media="(max-width: 767px)"') && shell.include?("hero_landscape"),
       "the shell preloads a configured landscape image on narrow viewports")
tailwind_at = shell.index('href="/assets/css/tailwind.css"')
icons_at = shell.index("window.__pandorgaIconsHref")
check!(tailwind_at && icons_at && tailwind_at < icons_at,
       "tailwind must be linked before the icon scripts")

home_css = HOME_CSS.read
check!(home_css.include?("background: black"),
       "the plate waits on black")
plate_img = home_css[/^\.home-hero-plate img \{.*?\n\}/m]
check!(plate_img&.match?(/opacity:\s*0/) && plate_img.match?(/transition:[^;]*opacity/m),
       "the photograph stays hidden and fades in, got #{plate_img.inspect}")
shown = home_css[/^\.home-hero-plate img\.is-shown \{.*?\n\}/m]
check!(shown&.match?(/opacity:\s*1/),
       "a ready photograph fades to full opacity, got #{shown.inspect}")
check!(!home_css.include?("aspect-ratio: 4 / 3"),
       "the phone plate must not cover-crop the portrait into 4:3")
landscape_plate = home_css[/@media \(max-width: 767px\) \{\s*\.home-hero-plate--landscape \{[^}]*\}/m]
check!(landscape_plate&.include?("aspect-ratio: 16 / 9"),
       "a landscape plate is 16:9 on a phone, got #{landscape_plate.inspect}")
landscape_img = home_css[/\.home-hero-plate--landscape img \{[^}]*\}/m]
check!(landscape_img&.include?("object-fit: contain") && landscape_img.include?("opacity: 1"),
       "the 16:9 file is shown whole and can paint without the portrait fade, got #{landscape_img.inspect}")

runtime = RUNTIME.read
start = runtime.index("function heroPortraitEntries")
finish = runtime.index("function hydratePageFragments")
check!(start && finish && finish > start, "hero portrait functions must precede hydratePageFragments")
body = runtime[start...finish]
check!(body.include?("loadJson('pages/home/portraits.json')"), "the runtime must fetch the exported list")
check!(body.include?("pickHeroPortrait(entries, Math.random)"),
       "the draw must use Math.random once per load")
check!(body.include?("return next();"),
       "a failed image load must try the next pool file")
check!(body.include?("probe.onload = function ()"), "src must change from the image onload")
onload = body[/probe\.onload = function \(\) \{.*?\n        \};/m]
check!(onload&.include?("img.src = nextSrc") && onload.include?("img.alt = nextAlt") &&
         onload.include?("img.classList.add('is-shown')"),
       "src, alt, and the fade-in must be applied together after load, got #{onload.inspect}")
check!(onload && onload.index("applyHeroPortraitSources") && onload.index("img.src = nextSrc") &&
         onload.index("applyHeroPortraitSources") < onload.index("img.src = nextSrc"),
       "srcset must be applied before src so the full file is not the first request")
check!(body.include?("probe.fetchPriority = 'high'"),
       "the portrait probe must use fetchPriority high")
check!(body.include?("heroLandscapeActive") && body.include?("data-hero-landscape"),
       "a narrow viewport with hero_landscape must not swap in a portrait")
check!(runtime.include?("hydrateHeroPortrait();"),
       "hydratePageFragments must draw the plate before the later fragment chain")
plate_call = runtime.index("function hydratePageFragments")
later = runtime.index("hydrateHomeSections();", plate_call || 0)
check!(plate_call && runtime.index("hydrateHeroPortrait();", plate_call) &&
         runtime.index("hydrateHeroPortrait();", plate_call) < later,
       "the plate draw must start at the beginning of hydratePageFragments")
onerror = body[/probe\.onerror = function \(\) \{.*?\n        \};/m]
check!(onerror && !onerror.include?("img.src") && !onerror.include?("is-shown"),
       "a failed image load must leave the plate black, got #{onerror.inspect}")
check!(!body.include?("sessionStorage") && !body.include?("localStorage"),
       "the draw must not persist a choice")
check!(runtime.include?("hydrateHeroPortrait();"), "hydratePageFragments must draw the plate")

# ── AC-HERO-06 / AC-HERO-07 ─────────────────────────────────────────────────

stdout, stderr, status = Open3.capture3("node", PICKER.to_s)
print stdout
warn stderr unless stderr.strip.empty?
check!(status.success?, "picker cases failed")

# ── AC-HERO-02 ──────────────────────────────────────────────────────────────

if pool_names == personal_pool
Dir.mktmpdir("hero-portraits") do |dir|
  out = Pathname.new(dir).join("export")
  env = { "CONTENT_API_BASE_URL" => "", "CONTENT_EXPORT_SKIP_VALIDATE" => "1" }
  command = ["ruby", EXPORT.to_s, ROOT.join("content").to_s, out.to_s]
  output, export_status = Open3.capture2e(env, *command, chdir: ROOT.to_s)
  check!(export_status.success?, "export failed:\n#{output}")

  exported = out.join("pages/home/portraits.json")
  check!(exported.file?, "the export must write pages/home/portraits.json")
  payload = JSON.parse(exported.read)
  expected = HeroPortraits.entries(ROOT.join("content"))
  check!(payload == expected, "the exported list must be the hero folder, got #{payload.inspect}")
  srcs = payload.map { |entry| entry["src"] }
  check!(srcs == pool_names.map { |name| "/media/images/hero/#{name}" },
         "the export must name the four photographs, got #{srcs.inspect}")
  check!(srcs.none? { |src| src.include?("profile-monologue") },
         "the deleted monologue file must not stay in the draw")

  manifest = JSON.parse(out.join("manifest.json").read)
  listed = Array(manifest.dig("files", "page_headers"))
  check!(listed.include?("pages/home/portraits.json"),
         "manifest page_headers must include the portrait list, got #{listed.inspect}")
end
end

puts "All home hero portrait checks passed."

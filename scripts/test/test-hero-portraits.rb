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
# AC-HERO-08 one 16:9 frame at every width (PLT-AC-51): no landscape file,
#            no picture source, no width switch

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
check!(hero_imgs.length == 1 && hero_imgs.first.include?('width="1600"') &&
         hero_imgs.first.include?('height="900"'),
       "AC-HERO-08: one 1600×900 plate image, got #{hero_imgs.inspect}")
check!(!layout.include?("hero_landscape") && !layout.include?("data-hero-landscape") &&
         !layout.include?("<picture") && !layout.include?("<source"),
       "AC-HERO-08: the layout has no landscape file and no picture source")
shell = SHELL.read
check!(!shell.include?("hero_landscape") && !shell.match?(/rel="preload" as="image"/),
       "AC-HERO-08: the shell preloads no hero image")
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
# Scoped to the hero rules: other home cards (the Rascunhos posters,
# PLT-AC-49) may use 4:3. Any spacing of 4/3 counts.
hero_crops = home_css.scan(/([^{}]*home-hero[^{}]*)\{([^{}]*)\}/).select do |_selector, body|
  body.match?(/aspect-ratio:\s*4\s*\/\s*3/)
end
check!(hero_crops.empty?,
       "the phone plate must not cover-crop the portrait into 4:3, got #{hero_crops.map(&:first).map(&:strip).inspect}")
portrait_crops = home_css.scan(/([^{}]*home-hero[^{}]*)\{([^{}]*)\}/).select do |_selector, body|
  body.match?(/aspect-ratio:\s*3\s*\/\s*4/)
end
check!(portrait_crops.empty?,
       "AC-HERO-08: no hero rule keeps the 3:4 frame, got #{portrait_crops.map(&:first).map(&:strip).inspect}")
base_plate = home_css[/^\.home-hero-plate \{.*?\n\}/m]
check!(base_plate&.match?(%r{aspect-ratio:\s*16\s*/\s*9}),
       "AC-HERO-08: the plate is 16:9 at every width, got #{base_plate.inspect}")
check!(!home_css.include?("home-hero-plate--landscape"),
       "AC-HERO-08: the landscape plate class is gone")

runtime = RUNTIME.read
start = runtime.index("function heroPortraitEntries")
finish = runtime.index("function hydratePageFragments")
check!(start && finish && finish > start, "hero portrait functions must precede hydratePageFragments")
body = runtime[start...finish]
check!(body.include?("loadJson('pages/home/portraits.json')"), "the runtime must fetch the exported list")
check!(body.include?("pickHeroPortrait(entries, Math.random"),
       "the draw must use Math.random once per load")
check!(body.include?("data-hero-portrait-prefer"),
       "optional prefer pin must be read from data-hero-portrait-prefer")
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
check!(!body.include?("landscape") && !body.include?("matchMedia"),
       "AC-HERO-08: one draw at every width, with no landscape field and no width switch")
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
  check!(payload.none? { |entry| entry.key?("landscape") },
         "AC-HERO-08: the export writes no landscape field")
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

#!/usr/bin/env ruby
# frozen_string_literal: true

# Lighthouse mobile release rule and the non-blocking icon sheet.
# PLT-AC-24, PLT-AC-25.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

def fail!(message)
  warn "FAIL test-lighthouse-policy: #{message}"
  exit 1
end

docs = {
  "spec" => ROOT.join("docs/spec.md").read,
  "contributing" => ROOT.join("CONTRIBUTING.md").read,
  "readme" => ROOT.join("README.md").read
}
shell = ROOT.join("_layouts/shell.html").read
base = ROOT.join("assets/css/base.css").read
script = ROOT.join("scripts/lighthouse-home.sh").read
workflow = ROOT.join(".github/workflows/validate.yml").read
release = ROOT.join(".github/workflows/publish-gem.yml").read

docs.each do |name, text|
  flat = text.gsub(/\s+/, " ")
  fail!("#{name} does not require 90 or above") unless flat.include?("90 or above")
  fail!("#{name} does not limit 75 to 89 to a bug fix") unless flat.include?("only to ship a bug fix")
  fail!("#{name} does not require the performance campaign") unless flat.include?("urgent performance campaign")
  fail!("#{name} does not forbid a score below 75") unless flat.include?("Below 75 is never acceptable")
  fail!("#{name} does not limit the floors to releases") unless flat.include?("apply to releases")
  fail!("#{name} does not allow a lower pull-request score") unless flat.include?("may score lower")
  fail!("#{name} does not allow modular work") unless flat.include?("modular")
end

spec = docs.fetch("spec")
contributing = docs.fetch("contributing")

fail!("spec dropped the slower-release reason") unless spec.include?("slower release is better than a broken one")
fail!("contributing dropped the slower-release reason") unless contributing.include?("slower release is better than a broken one")

fail!("lighthouse script is not the CI check") unless workflow.include?("./scripts/lighthouse-home.sh")
fail!("pull requests still fail the lighthouse gate") unless workflow.include?("LIGHTHOUSE_MODE: warn")
fail!("release build does not enforce the score") unless release.include?("LIGHTHOUSE_MODE: enforce")
fail!("tag builds do not run the release gate") unless release.include?('tags: ["v*"]')
fail!("lighthouse script lost the fail floor") unless script.include?("FAIL_BELOW=75")
fail!("lighthouse script lost the warn floor") unless script.include?("WARN_BELOW=90")
fail!("lighthouse script lost enforce mode") unless script.include?('LIGHTHOUSE_MODE:-enforce')
fail!("warn mode still fails the run") unless script.include?('mode == "enforce"')
fail!("a non-bug-fix release can publish below 90") unless script.include?('bugfix != "1"')
fail!("release workflow cannot mark a bug fix") unless release.include?("LIGHTHOUSE_BUGFIX")
fail!("spec still publishes a feature below 90") unless spec.include?("LIGHTHOUSE_BUGFIX=1")
fail!("contributing still publishes a feature below 90") unless contributing.include?("LIGHTHOUSE_BUGFIX=1")
fail!("readme still publishes a feature below 90") unless docs.fetch("readme").include?("LIGHTHOUSE_BUGFIX=1")
fail!("lighthouse script is not a single mobile run") unless script.include?("--form-factor=mobile")
fail!("lighthouse script repeats runs") if script.include?("--repeat")
fail!("example server is still one-thread HTTP/1.0") if script.include?("python3 -m http.server")
server = ROOT.join("scripts/lighthouse_server.py").read
fail!("example server does not gzip") unless server.include?('Content-Encoding", "gzip"')
fail!("example server is not concurrent") unless server.include?("ThreadingHTTPServer")
fail!("icon face is preloaded") if shell.include?("rel=\"preload\" as=\"style\" href=\"{{ _symbols_href }}\"")

screen = shell.sub(%r{<noscript>.*?</noscript>}m, "")
fail!("Material Symbols sheet is missing") unless shell.include?("Material+Symbols+Outlined")
fail!("screen still has a flag stylesheet link") if screen.match?(/<link\b[^>]*flag-icons/)
fail!("flag sheet is not deferred until load") unless screen.include?("flag-icons@7.2.3")
fail!("icon face is the full variable font") if shell.include?("0..1&display=swap")
fail!("icon face is not a named subset") unless shell.include?("icon_names=")
fail!("icon subset is not a head link") unless screen.include?('id="pandorga-icons"')

fonts = ROOT.join("_includes/theme/font-loader.html").read
fail!("text faces are preloaded") if fonts.include?('rel="preload"')
fail!("text face still waits for the load event") if fonts.include?("addEventListener('load'")
fail!("text face stylesheet is missing") unless fonts.include?('rel="stylesheet" href="{{ fonts_href }}"')

marked = ROOT.join("_includes/content-runtime/00-config.html").read
fail!("markdown library still blocks parsing") unless marked.include?("<script defer ")
fail!("markdown library source changed") unless marked.include?("marked@15.0.7/marked.min.js")

fail!("spec still withholds the text face until load") unless spec.include?("text-face stylesheet is a head link")
fail!("lighthouse example is not the full site") unless script.include?("examples/full")
fail!("lighthouse example can ship without a static summary") unless script.include?("data-content-static")
summary = ROOT.join("examples/full/content/pages/cv/summary.md").read
fail!("full summary dropped the fixture sentence") unless summary.include?("Ada Example designs publishing frames")
fail!("full summary is too short to be the hero paint") unless summary.scan(".").length >= 3
fail!("spec still lets the markdown library block parsing") unless spec.include?("markdown library loads with `defer`")
fail!("lighthouse script hides the metric breakdown") unless script.include?("largest-contentful-paint")

icon = base[/\.material-symbols-outlined\.material-symbols-outlined \{.*?\n\}/m]
fail!("icon rule missing") unless icon
fail!("icon box is not 1em") unless icon.include?("width: 1em;") && icon.include?("height: 1em;")
fail!("icon size can still jump when the Google sheet arrives") unless icon.include?("font-size: inherit;")
fail!("icon box does not clip the fallback word") unless icon.include?("overflow: hidden;")
fail!("content runtime still precedes the page") unless shell.index("{{ content }}") && shell.index("page/content-runtime.html") > shell.index("{{ content }}")
band = File.read(File.expand_path("../../_includes/home/band-listing.html", __dir__))
fail!("band title is still painted by script") unless band.include?('data-content-section-title>{{ _title }}')
fail!("band note is still painted by script") unless band.include?("page_headers")
fail!("project inventory has a name and no role") unless band.include?('role="region"') && band.include?('aria-label="Project inventory"')
headers = File.read(File.expand_path("../../_plugins/content_headers.rb", __dir__))
fail!("page headers are not loaded at build time") unless headers.include?('site.data["page_headers"]')
home = File.read(File.expand_path("../../_layouts/home.html", __dir__))
fail!("hero subtitle is still painted by script") unless home.include?("page_headers.home") && home.include?("data-content-static")

puts "PASS test-lighthouse-policy"

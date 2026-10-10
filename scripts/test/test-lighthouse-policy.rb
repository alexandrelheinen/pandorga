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

docs.each do |name, text|
  fail!("#{name} does not require 90 or above") unless text.include?("90 or above")
  fail!("#{name} does not limit 75 to 89 to a bug fix") unless text.include?("only to ship a bug fix")
  fail!("#{name} does not require the performance campaign") unless text.include?("urgent performance campaign")
  fail!("#{name} does not forbid a score below 75") unless text.include?("Below 75 is never acceptable")
end

spec = docs.fetch("spec")
contributing = docs.fetch("contributing")

fail!("spec dropped the slower-release reason") unless spec.include?("slower release is better than a broken one")
fail!("contributing dropped the slower-release reason") unless contributing.include?("slower release is better than a broken one")

fail!("lighthouse script is not the CI check") unless workflow.include?("./scripts/lighthouse-home.sh")
fail!("lighthouse script lost the fail floor") unless script.include?("FAIL_BELOW=75")
fail!("lighthouse script lost the warn floor") unless script.include?("WARN_BELOW=90")
fail!("lighthouse script is not a single mobile run") unless script.include?("--form-factor=mobile")
fail!("lighthouse script repeats runs") if script.include?("--repeat")

screen = shell.sub(%r{<noscript>.*?</noscript>}m, "")
fail!("Material Symbols sheet is missing") unless shell.include?("Material+Symbols+Outlined")
fail!("Material Symbols sheet still blocks first paint") unless screen.include?('media="print" onload="this.media=\'all\'"')
fail!("screen still has a blocking Material Symbols stylesheet") if screen.match?(/rel="stylesheet"[^>]*Material\+Symbols|Material\+Symbols[^>]*rel="stylesheet"/m)

icon = base[/\.material-symbols-outlined\.material-symbols-outlined \{.*?\n\}/m]
fail!("icon rule missing") unless icon
fail!("icon box is not 1em") unless icon.include?("width: 1em;") && icon.include?("height: 1em;")
fail!("icon size can still jump when the Google sheet arrives") unless icon.include?("font-size: inherit;")
fail!("icon box does not clip the fallback word") unless icon.include?("overflow: hidden;")
fail!("content runtime still precedes the page") unless shell.index("{{ content }}") && shell.index("page/content-runtime.html") > shell.index("{{ content }}")
band = File.read(File.expand_path("../../_includes/home/band-listing.html", __dir__))
fail!("band title is still painted by script") unless band.include?('data-content-section-title>{{ _title }}')
fail!("band note is still painted by script") unless band.include?("page_headers")
headers = File.read(File.expand_path("../../_plugins/content_headers.rb", __dir__))
fail!("page headers are not loaded at build time") unless headers.include?('site.data["page_headers"]')
home = File.read(File.expand_path("../../_layouts/home.html", __dir__))
fail!("hero subtitle is still painted by script") unless home.include?("page_headers.home") && home.include?("data-content-static")

puts "PASS test-lighthouse-policy"

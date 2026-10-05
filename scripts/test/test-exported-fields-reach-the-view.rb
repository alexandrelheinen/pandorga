#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: every field the exporter writes must survive the trip to the page.
#
# Between scripts/content/export-content-json.rb and a rendered card sit two
# copy steps that drop fields silently:
#
#   writing_index.json  --writingIndexAsListingItem-->  { front_matter }
#   collections/*.json  --hydrateFrontMatter-------->  { front_matter }
#
# The first is an explicit field whitelist, so an exported field stays
# invisible until someone remembers to add a line to it; that is how
# `language` was exported for weeks and never appeared on a card. The second
# used to return early before promoting the payload date, so no detail page
# showed a date at all. Neither failure changes the build's exit code.
#
# So: export for real, then run both copy steps through the real runtime and
# compare key by key. A new exporter field is covered the day it is added —
# either it reaches the view, or it goes on the documented exclusion list in
# scripts/test/render-parity/run-field-flow-checks.mjs.

require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_SCRIPT = ROOT.join("scripts/content/export-content-json.rb")
CHECKS = Pathname.new(__dir__).join("render-parity", "run-field-flow-checks.mjs")

def fail!(message)
  warn message
  exit 1
end

puts "Testing that exported fields reach the view..."

fail!("missing #{CHECKS}") unless CHECKS.file?

Dir.mktmpdir("field-flow-") do |tmp|
  out_dir = Pathname.new(tmp).join("_content_json")

  stdout, stderr, status = Open3.capture3(
    { "CONTENT_API_BASE_URL" => "" },
    "ruby", EXPORT_SCRIPT.to_s, "content", out_dir.to_s,
    chdir: ROOT.to_s
  )
  fail!("export-content-json.rb failed:\n#{stderr}\n#{stdout}") unless status.success?

  stdout, stderr, status = Open3.capture3(
    "node", CHECKS.to_s, out_dir.to_s, chdir: ROOT.join("scripts").to_s
  )
  print stdout
  unless status.success?
    warn stderr unless stderr.strip.empty?
    fail!("An exported field never reaches the page.")
  end
end

puts "All exported-field flow checks passed."

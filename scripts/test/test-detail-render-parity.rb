#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: the build-time and browser detail views must emit the same contract.
#
# Detail pages exist twice. The public site assembles them in the browser from
# _includes/content-runtime/50-detail.html, which calls the shared ledger
# blocks. The private/studio build renders them at build time from
# _layouts/text.html, which reimplements the tag chips and the language pill
# in Liquid — it has no way to call the JS. One stylesheet,
# assets/css/ledger/detail.css, serves both, so a class renamed on one side
# silently unstyles the other, and the language table can drift into two
# different vocabularies without anything failing.
#
# The layout already states this contract in a comment. This makes it a gate.

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CHECKS = Pathname.new(__dir__).join("render-parity", "run-detail-parity-checks.mjs")

def fail!(message)
  warn message
  exit 1
end

puts "Testing detail view render parity (Liquid build vs browser runtime)..."

fail!("missing #{CHECKS}") unless CHECKS.file?

stdout, stderr, status = Open3.capture3("node", CHECKS.to_s, chdir: ROOT.join("scripts").to_s)

print stdout
unless status.success?
  warn stderr unless stderr.strip.empty?
  fail!("The two detail render paths have drifted apart.")
end

puts "All detail render parity checks passed."

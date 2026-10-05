#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: an element renders only when the field backing it is present.
#
# This is the site's central editorial invariant, and the one the build cannot
# see. The shared ledger blocks run in the browser, so `jekyll build` succeeds
# whether a card shows a language pill for a piece that never declared one, an
# empty poster plate where there is no thumbnail, or a meta strip that ends in
# a dangling slash. Every failure of this kind has to be caught by executing
# the blocks, which is what scripts/test/render-parity/run-absent-field-checks.mjs
# does against the real _includes/content-runtime/43-blocks.html.
#
# The positive half of the contract — present field, present element — lives in
# scripts/test/render-parity/blocks/*.json, so a block cannot pass this gate by
# rendering nothing at all.

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CHECKS = Pathname.new(__dir__).join("render-parity", "run-absent-field-checks.mjs")

def fail!(message)
  warn message
  exit 1
end

puts "Testing the absent-field / absent-element rule..."

fail!("missing #{CHECKS}") unless CHECKS.file?

stdout, stderr, status = Open3.capture3(
  "node", CHECKS.to_s, chdir: ROOT.join("scripts").to_s
)

print stdout
unless status.success?
  warn stderr unless stderr.strip.empty?
  fail!("Absent fields rendered elements. An absent field means an absent element.")
end

puts "All absent-field / absent-element checks passed."

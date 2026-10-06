#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
FIXTURE_DIR = Pathname.new(__dir__).join("render-parity", "blocks")
RUNNER = Pathname.new(__dir__).join("render-parity", "run-block-fixture.mjs")

# The block half of test-content-render-parity, without its Markdown half.
# That gate needs `marked` from scripts/node_modules, which CI never installs,
# so it stays off validate.sh; the ledger blocks fall back cleanly without it.

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

puts "Testing ledger block fixtures..."

paths = Dir.glob(FIXTURE_DIR.join("*.json")).sort
check! paths.any?, "no ledger block fixtures found"

paths.each do |fixture_path|
  stdout, stderr, status = Open3.capture3(
    "node", RUNNER.to_s, fixture_path, chdir: ROOT.join("scripts").to_s
  )
  check! status.success?, "#{File.basename(fixture_path)} failed:\n#{stderr}\n#{stdout}"
  puts "  #{stdout.strip}"
end

puts "All ledger block fixtures passed."

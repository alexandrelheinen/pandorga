#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
FIXTURE_DIR = Pathname.new(__dir__).join("render-parity")
RUNNER = FIXTURE_DIR.join("run-fixture.mjs")

# The shared ledger blocks (43-blocks.html) render listings in the browser, so
# a Jekyll build never executes them and no Ruby gate can see their output.
# Their fixtures call the real runtime through load-runtime.mjs.
BLOCK_DIR = FIXTURE_DIR.join("blocks")
BLOCK_RUNNER = FIXTURE_DIR.join("run-block-fixture.mjs")

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

def run_fixtures!(runner, paths, label)
  check! paths.any?, "no #{label} fixtures found"
  paths.each do |fixture_path|
    stdout, stderr, status = Open3.capture3(
      "node", runner.to_s, fixture_path, chdir: ROOT.join("scripts").to_s
    )
    check! status.success?, "#{File.basename(fixture_path)} failed:\n#{stderr}\n#{stdout}"
    puts "  #{stdout.strip}"
  end
end

puts "Testing content render parity..."

run_fixtures!(RUNNER, Dir.glob(FIXTURE_DIR.join("*.json")).sort, "markdown parity")
run_fixtures!(BLOCK_RUNNER, Dir.glob(BLOCK_DIR.join("*.json")).sort, "ledger block")

puts "All content render parity tests passed."

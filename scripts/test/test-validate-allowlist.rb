#!/usr/bin/env ruby
# frozen_string_literal: true

# A listed gate that is not on disk must fail the run. Skipping it lets a
# renamed test disappear from CI while validate.sh still exits 0.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
SCRIPT = ROOT.join("scripts/validate.sh")

def fail!(message)
  warn "FAIL test-validate-allowlist: #{message}"
  exit 1
end

source = SCRIPT.read
block = source[/if \[\[ ! -f "\$test" \]\]; then.*?fi/m]
fail!("missing-file branch not found") unless block
fail!("a missing listed test must set failed=1") unless block.include?("failed=1")
fail!("a missing listed test must not be skipped") if block.include?("skip")

listed = source.scan(%r{scripts/test/test-[A-Za-z0-9_.-]+})
fail!("allowlist is empty") if listed.empty?

missing = listed.uniq.reject { |rel| ROOT.join(rel).file? }
fail!("listed tests are not on disk: #{missing.join(', ')}") unless missing.empty?

puts "PASS test-validate-allowlist"

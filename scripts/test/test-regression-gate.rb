#!/usr/bin/env ruby
# frozen_string_literal: true

# Additive headless browser regression gate (PLT-AC-73).
require "pathname"
require "open3"

ROOT = Pathname.new(__dir__).join("../..").expand_path
MJS = ROOT.join("scripts/test/test-regression-gate.mjs")

unless MJS.file?
  warn "FAIL test-regression-gate: missing #{MJS}"
  exit 1
end

stdout, stderr, status = Open3.capture3("node", MJS.to_s, chdir: ROOT.to_s)
if status.success?
  puts stdout
else
  warn "FAIL test-regression-gate:\n#{stdout}\n#{stderr}"
  exit 1
end

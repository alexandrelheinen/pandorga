# frozen_string_literal: true

# PLT-AC-103 — rendered monotonicity gate (strength upper/face, pool text band).
require "pathname"
require "open3"

ROOT = Pathname.new(__dir__).join("../..").expand_path
MJS = ROOT.join("scripts/test/test-home-hero-overlay-monotonic.mjs")

unless MJS.file?
  warn "FAIL test-home-hero-overlay-monotonic: missing #{MJS}"
  exit 1
end

stdout, stderr, status = Open3.capture3("node", MJS.to_s, chdir: ROOT.to_s)
if status.success?
  puts stdout
else
  warn "FAIL test-home-hero-overlay-monotonic:\n#{stdout}\n#{stderr}"
  exit 1
end

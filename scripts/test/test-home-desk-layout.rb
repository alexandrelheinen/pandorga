# frozen_string_literal: true

# PLT-AC-88 / PLT-AC-98/99 — rendered desktop projects list + hero +4pt.
require "pathname"
require "open3"

ROOT = Pathname.new(__dir__).join("../..").expand_path
MJS = ROOT.join("scripts/test/test-home-desk-layout.mjs")

unless MJS.file?
  warn "FAIL test-home-desk-layout: missing #{MJS}"
  exit 1
end

stdout, stderr, status = Open3.capture3("node", MJS.to_s, chdir: ROOT.to_s)
if status.success?
  puts stdout
else
  warn "FAIL test-home-desk-layout:\n#{stdout}\n#{stderr}"
  exit 1
end

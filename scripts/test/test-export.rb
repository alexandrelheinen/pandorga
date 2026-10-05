# frozen_string_literal: true

# Refs: PLT-AC-6, PLT-AC-7, PLT-AC-12
require "pathname"
require "json"
require "open3"
require "fileutils"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXAMPLE = ROOT.join("examples/minimal")
EXE = ROOT.join("exe/pandorga")
DEST = ROOT.join("tmp/export-test")

FileUtils.rm_rf(DEST)
env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
stdout, stderr, status = Open3.capture3(
  env, "ruby", EXE.to_s, "export",
  EXAMPLE.join("content").to_s, DEST.to_s
)
unless status.success?
  warn "FAIL test-export: #{stdout}\n#{stderr}"
  exit 1
end

manifest = JSON.parse(DEST.join("manifest.json").read)
unless manifest["schema_version"] == 1
  warn "FAIL test-export: schema_version missing or wrong"
  exit 1
end

hello = JSON.parse(DEST.join("collections/articles/2026-01-01-hello.json").read)
unless hello["title"] == "Hello from Pandorga"
  warn "FAIL test-export: title not exported"
  exit 1
end
if hello.key?("body_extended")
  warn "FAIL test-export: private field leaked"
  exit 1
end

puts "PASS test-export"

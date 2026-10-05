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
env = {
  "RUBYOPT" => "-I#{ROOT.join('lib')}",
  "PANDORGA_SITE_ROOT" => EXAMPLE.to_s,
  "CONTENT_API_BASE_URL" => "",
  "CONTENT_EXPORT_SKIP_VALIDATE" => "1"
}
stdout, stderr, status = Open3.capture3(
  env, "ruby", EXE.to_s, "export",
  "content", DEST.to_s,
  chdir: EXAMPLE.to_s
)
unless status.success?
  warn "FAIL test-export: #{stdout}\n#{stderr}"
  exit 1
end

manifest = JSON.parse(DEST.join("manifest.json").read)
unless manifest["schema_version"] == 1
  warn "FAIL test-export: schema_version missing or wrong: #{manifest['schema_version'].inspect}"
  exit 1
end

hello = DEST.join("collections/articles/2026-01-01-hello.json")
unless hello.file?
  warn "FAIL test-export: missing #{hello}"
  exit 1
end
payload = JSON.parse(hello.read)
title = payload["title"] || payload.dig("front_matter", "title")
unless title.to_s.include?("Hello")
  warn "FAIL test-export: title not exported (#{title.inspect})"
  exit 1
end
if payload.key?("body_extended") || payload.dig("front_matter", "body_extended")
  warn "FAIL test-export: private field leaked"
  exit 1
end

puts "PASS test-export"

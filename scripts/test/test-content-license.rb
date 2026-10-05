#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

require_relative "../lib/content_license"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_ROOT = REPO_ROOT.join("_content_json")

def check!(condition, message)
  raise message unless condition
end

puts "Testing content license export..."

config_license = ContentLicense.load(REPO_ROOT)
check!(config_license["id"] == "CC-BY-4.0", "content_license.id must be CC-BY-4.0 in _config.yml")

run_export = !EXPORT_ROOT.join("manifest.json").file?
if run_export
  system("ruby", REPO_ROOT.join("scripts/content/export-content-json.rb").to_s, "content", "_content_json") || exit(1)
end

manifest_path = EXPORT_ROOT.join("manifest.json")
check!(manifest_path.file?, "manifest.json missing after export")

manifest = JSON.parse(manifest_path.read)
check!(manifest["content_license"].is_a?(Hash), "manifest.json missing content_license")
check!(manifest["content_license"]["id"] == "CC-BY-4.0", "manifest content_license.id must be CC-BY-4.0")
check!(manifest["content_license"]["url"].to_s.include?("creativecommons.org"), "manifest content_license.url must point to Creative Commons")

%w[articles posts].each do |collection|
  sample = manifest.dig("files", collection, 0)
  check!(sample, "manifest.files.#{collection} is empty")

  json_path = EXPORT_ROOT.join(sample)
  payload = JSON.parse(json_path.read)
  check!(payload["license"].is_a?(Hash), "#{sample} missing license object")
  check!(payload["license"]["id"] == "CC-BY-4.0", "#{sample} license.id must be CC-BY-4.0")
  check!(payload["copyright"].to_s.include?("©"), "#{sample} missing copyright notice")
end

puts "All content license tests passed."

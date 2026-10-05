# frozen_string_literal: true

# Refs: PLT-AC-3 — homepage bands derive from the registry.
require "pathname"
require "yaml"

ROOT = Pathname.new(__dir__).join("../..").expand_path
$LOAD_PATH.unshift(ROOT.join("lib").to_s)
require "pandorga/registry"

config = YAML.safe_load(ROOT.join("examples/full/_config.yml").read, aliases: true)
pages = PandorgaRegistry.pages(config)
bands = PandorgaRegistry.home_bands(pages)

kinds = bands.map { |b| b["kind"] }
unless kinds == %w[portfolio articles blog index]
  warn "FAIL test-registry-home: unexpected band kinds #{kinds.inspect}"
  exit 1
end

index = bands.find { |b| b["kind"] == "index" }
panel_keys = index["pages"].map { |p| p["key"] }
unless panel_keys == %w[resources network bibliography]
  warn "FAIL test-registry-home: index panels #{panel_keys.inspect}"
  exit 1
end

layout = PandorgaRegistry.layout_for({ "template" => "portfolio" })
unless layout == "projects"
  warn "FAIL test-registry-home: portfolio layout expected projects, got #{layout}"
  exit 1
end

puts "PASS test-registry-home"

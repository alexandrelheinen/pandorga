#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "set"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
ALLOWLIST = JSON.parse(File.read(ROOT.join("scripts/cdn-allowlist.json")))
ALLOWED = ALLOWLIST.fetch("allowed_urls").to_set
SCAN_DIRS = ALLOWLIST.fetch("scan_globs")

CDN_ATTR_RE = /
  (?:src|href)\s*=\s*["']
  (https?:\/\/[^"']+)
  ["']
/ix

errors = []

SCAN_DIRS.each do |relative|
  dir = ROOT.join(relative)
  next unless dir.directory?

  Dir.glob(dir.join("**/*.{html,js,liquid}")).sort.each do |file|
    path = Pathname.new(file)
    text = path.read
    text.scan(CDN_ATTR_RE).flatten.each do |url|
      next unless url.include?("cdn.jsdelivr.net") || url.include?("cdn.tailwindcss.com")

      next if ALLOWED.include?(url)

      errors << "#{path.relative_path_from(ROOT)}: unlisted CDN URL #{url}"
    end
  end
end

if errors.any?
  warn "CDN pin validation failed:"
  errors.each { |line| warn "  - #{line}" }
  exit 1
end

puts "CDN pin validation OK (#{ALLOWED.size} allowed URLs)."

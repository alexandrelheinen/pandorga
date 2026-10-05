#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require "pathname"
require_relative "../lib/content_storage_config"

REPO_ROOT = ContentStorageConfig.repo_root
REDIRECTS_FILE = REPO_ROOT.join("_redirects")
STUDIO_FILE = REPO_ROOT.join("studio/index.html")
EXPORT_SCRIPT = REPO_ROOT.join("scripts/content/export-content-json.rb")

def fail!(message)
  raise message
end

def check!(condition, message)
  fail!(message) unless condition
end

base = ContentStorageConfig.base_url
check!(base && !base.empty?, "_config.yml content_api_base_url must be set")

legacy_host = ContentStorageConfig::LEGACY_GCS_HOST
[
  ["_config.yml", ContentStorageConfig.config_path.read],
  ["_redirects", REDIRECTS_FILE.read],
  ["studio/index.html", STUDIO_FILE.read],
  ["scripts/content/export-content-json.rb", EXPORT_SCRIPT.read]
].each do |label, text|
  check!(!text.include?(legacy_host),
         "#{label} still references GCS (#{legacy_host})")
end

if ContentStorageConfig.placeholder?(base)
  puts "SKIP: R2 URL alignment checks (content_api_base_url is still placeholder: #{base})"
  puts "      Fill the URL per docs/ops/cloudflare.md before production cutover."
  exit 0
end

redirects = REDIRECTS_FILE.read
media_line = redirects.lines.find { |line| line.start_with?("/media/*") }
check!(media_line, "_redirects must define /media/* → R2")
check!(media_line.include?(base),
       "/media/* redirect must use content_api_base_url (#{base}); got: #{media_line.strip}")

studio = STUDIO_FILE.read
# Self-hosted Studio SPA: media is HTTPS or /media/* (redirected via _redirects).
# Do not require a Decap-era CONTENT_MEDIA_BASE constant in index.html.
check!(!studio.match?(%r{storage\.googleapis\.com|googleapis\.com/storage}),
       "studio/index.html must not hardcode a GCS media host")
check!(!studio.include?(legacy_host),
       "studio/index.html must not reference legacy GCS host")

puts "R2 config consistency OK (#{base})"

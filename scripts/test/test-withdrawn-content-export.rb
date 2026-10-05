#!/usr/bin/env ruby
# frozen_string_literal: true

# Objects taken down for copyright / unpublished drafts must not re-enter the
# public export. The R2 sync deletes remote keys that are absent locally, so
# this list is also the prune set for a clean publish.

$stdout.sync = true
$stderr.sync = true

require "json"
require "open3"
require "pathname"
require "tmpdir"

require_relative "../lib/withdrawn_public_objects"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_SCRIPT = REPO_ROOT.join("scripts/content/export-content-json.rb")

WITHDRAWN_EXPORT_PATHS = WithdrawnPublicObjects::EXPORT_PATHS
STALE_PUBLIC_PHRASES = WithdrawnPublicObjects::STALE_PHRASES

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

def check_export!(out)
  manifest = JSON.parse(out.join("manifest.json").read)
  listed = Array(manifest["files"]).flat_map { |_key, paths| Array(paths) }

  WITHDRAWN_EXPORT_PATHS.each do |relative|
    check!(!out.join(relative).exist?, "export wrote withdrawn object #{relative}")
    check!(!listed.include?(relative), "manifest lists withdrawn object #{relative}")
  end

  export_text = out.glob("**/*.json").map(&:read).join("\n")
  STALE_PUBLIC_PHRASES.each do |phrase|
    check!(!export_text.include?(phrase), "export still contains withdrawn phrase #{phrase.inspect}")
  end
end

puts "Testing withdrawn objects stay out of the public export..."

existing = ARGV[0]
if existing
  out = Pathname.new(existing).expand_path
  check!(out.directory?, "export dir missing: #{out}")
  check_export!(out)
else
  Dir.mktmpdir("withdrawn-content-export-") do |dir|
    out = Pathname.new(dir).join("export")
    stdout, stderr, status = Open3.capture3(
      { "CONTENT_API_BASE_URL" => "" },
      "ruby", EXPORT_SCRIPT.to_s, "content", out.to_s,
      chdir: REPO_ROOT.to_s
    )
    fail!("export failed:\n#{stderr}\n#{stdout}") unless status.success?

    check_export!(out)
  end
end

puts "Withdrawn content export OK."

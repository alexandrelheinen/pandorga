#!/usr/bin/env ruby
# frozen_string_literal: true

# Keep unwrapMediaSrc (Pages CMS Markdown-autolink mangling of include src=)
# honest against a small Node mirror. The browser runtime and PDF exporter
# share the same contract.

require "pathname"
require "open3"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
SCRIPT = REPO_ROOT.join("scripts", "test", "test-unwrap-media-src.mjs")

puts "Testing unwrapMediaSrc (CMS autolink unwrap)..."

stdout, stderr, status = Open3.capture3("node", SCRIPT.to_s)
print stdout
warn stderr unless stderr.empty?
exit(status.exitstatus)

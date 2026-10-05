#!/usr/bin/env ruby
# frozen_string_literal: true

# The content runtime is assembled from a dozen Liquid partials into one
# inline <script>. A syntax error in any partial takes down every listing and
# detail view at once, and no Ruby gate would notice: the build succeeds and
# the page ships broken. Parse the assembled script the way a browser would.

require "pathname"
require "open3"
require "tmpdir"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
SITE_ROOT = REPO_ROOT.join("_site")

# One page per distinct runtime assembly. They all include the same partials
# today, but a layout could include a subset tomorrow.
CANDIDATES = [
  "pages/articles/index.html",
  "pages/blog/index.html",
  "pages/projects/index.html",
  "index.html"
].freeze

RUNTIME_PATTERN = /window\.ContentRuntime = \(function \(\) \{.*?\n  \}\)\(\);/m

def fail!(message)
  warn message
  exit 1
end

puts "Testing content runtime JS syntax..."

unless SITE_ROOT.directory?
  puts "  skipped: no _site build to inspect"
  exit 0
end

checked = 0

Dir.mktmpdir do |tmp|
  CANDIDATES.each do |relative|
    page = SITE_ROOT.join(relative)
    next unless page.file?

    match = page.read.match(RUNTIME_PATTERN)
    next if match.nil?

    script = Pathname.new(tmp).join("#{relative.tr('/', '-')}.js")
    script.write(match[0])

    _out, err, status = Open3.capture3("node", "--check", script.to_s)
    unless status.success?
      fail!("#{relative}: content runtime is not valid JavaScript\n#{err}")
    end

    checked += 1
    puts "  #{relative}: OK (#{match[0].bytesize} bytes)"
  end
end

fail!("no page contained a ContentRuntime block — did the runtime stop inlining?") if checked.zero?

puts "All content runtime JS syntax tests passed (#{checked} page(s))."

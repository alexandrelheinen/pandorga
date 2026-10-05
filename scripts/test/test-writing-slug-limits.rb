#!/usr/bin/env ruby
# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "pathname"

require_relative "../../_plugins/writing_slug_limits"

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

def assert_equal(expected, actual, message = nil)
  return if expected == actual

  label = message || "expected #{expected.inspect}, got #{actual.inspect}"
  raise "Assertion failed: #{label}"
end

def with_temp_writing_tree
  Dir.mktmpdir("writing-slug-limits") do |tmpdir|
    root = Pathname.new(tmpdir)
    yield root
  end
end

puts "Testing WritingSlugLimits..."

check! WritingSlugLimits.ascii_slug?("2026-06-26-escarnio")
check! !WritingSlugLimits.ascii_slug?("2026-06-26-escárnio"), "accented slug should not be ASCII"

assert_equal "2026-06-26-escarnio", WritingSlugLimits.transliterate_slug("2026-06-26-escárnio")
assert_equal "2026-04-16-otimismo-na-ciencia", WritingSlugLimits.transliterate_slug("2026-04-16-otimismo-na-ciência")
assert_equal "2026-06-24-por-que-eu-sai-do-mundo-do-drone", WritingSlugLimits.transliterate_slug("2026-06-24-por-que-eu-saí-do-mundo-do-drone")

with_temp_writing_tree do |root|
  posts_dir = root.join("content/collections/posts")
  FileUtils.mkdir_p(posts_dir)
  File.write(posts_dir.join("2026-06-26-escárnio.md"), "---\ntitle: Test\n---\n")

  errors = WritingSlugLimits.collect_errors(root)
  check! errors.any? { |error| error.include?("non-ASCII") }, "expected non-ASCII slug error"
  check! errors.any? { |error| error.include?("2026-06-26-escarnio") }, "expected transliterated suggestion"
end

with_temp_writing_tree do |root|
  posts_dir = root.join("content/collections/posts")
  FileUtils.mkdir_p(posts_dir)
  long_slug = "#{'a' * 45}"
  File.write(posts_dir.join("#{long_slug}.md"), "---\ntitle: Test\n---\n")

  errors = WritingSlugLimits.collect_errors(root)
  check! errors.any? { |error| error.include?("chars (max #{WritingSlugLimits::MAX_LENGTH})") },
         "expected length error"
end

repo_errors = WritingSlugLimits.collect_errors(Pathname.new(__dir__).join("..", ".."))
check! repo_errors.empty?, "repository slug validation failed:\n  - #{repo_errors.join("\n  - ")}"

puts "All WritingSlugLimits tests passed."

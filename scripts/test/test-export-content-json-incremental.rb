#!/usr/bin/env ruby
# frozen_string_literal: true

# Ensures export reuses identical JSON bytes instead of wiping OUTPUT_ROOT.

$stdout.sync = true
$stderr.sync = true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

require_relative "../lib/writing_index_contract"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_SCRIPT = REPO_ROOT.join("scripts/content/export-content-json.rb")

def fail!(message)
  warn message
  exit 1
end

def run_export!(out_dir)
  stdout, stderr, status = Open3.capture3(
    { "CONTENT_API_BASE_URL" => "" },
    "ruby", EXPORT_SCRIPT.to_s, "content", out_dir.to_s,
    chdir: REPO_ROOT.to_s
  )
  fail!("export failed:\n#{stderr}\n#{stdout}") unless status.success?

  stdout
end

Dir.mktmpdir("content-json-incremental-") do |dir|
  out = Pathname.new(dir).join("export")

  first = run_export!(out)
  fail!("first export missing write summary") unless first.include?("changed")

  sample = out.join("manifest.json")
  fail!("missing manifest") unless sample.file?

  mtime_before = sample.mtime
  content_before = sample.read
  sleep 1

  second = run_export!(out)
  fail!("second export should report unchanged files") unless second.match?(/unchanged=[1-9]/)

  # manifest embeds generated_at, so it should rewrite; pick a leaf that is stable.
  leaf = out.glob("collections/articles/*.json").min_by(&:to_s)
  fail!("no article JSON exported") unless leaf

  leaf_mtime = leaf.mtime
  leaf_body = leaf.read
  sleep 1
  run_export!(out)

  fail!("stable article JSON was rewritten") unless leaf.mtime == leaf_mtime
  fail!("stable article JSON bytes changed") unless leaf.read == leaf_body

  # Touch a published post body via chronology-insensitive check: rewriting the
  # same export dir must keep pruning functional (no crash) and keep manifest.
  fail!("manifest disappeared") unless sample.file?
  fail!("manifest became empty") if sample.read.strip.empty?
  fail!("first manifest snapshot unexpectedly empty") if content_before.strip.empty?

  puts "Export incremental write OK (sample #{leaf.relative_path_from(out)}, mtime preserved)"
  puts "Note: manifest may still rewrite because generated_at changes (#{mtime_before} -> #{sample.mtime})."
end

# Path filter: rebuild only the changed article plus indexes that embed dates/excerpts.
Dir.mktmpdir("content-json-path-filter-") do |dir|
  root = Pathname.new(dir)
  content = root.join("content")
  out = root.join("export")
  FileUtils.mkdir_p(content.join("collections/articles"))

  write_article = lambda do |stem, body|
    content.join("collections/articles/#{stem}.md").write(<<~MARKDOWN)
      ---
      title: #{stem}
      key: #{stem}
      date: 2026-08-22
      published: true
      ---
      #{body}
    MARKDOWN
  end

  write_article.call("filter-a", "First A")
  write_article.call("filter-b", "First B")

  run = lambda do |changed|
    env = {
      "CONTENT_API_BASE_URL" => "",
      "CONTENT_EXPORT_SKIP_VALIDATE" => "1"
    }
    env["CONTENT_EXPORT_CHANGED_PATHS"] = changed unless changed.to_s.empty?
    stdout, stderr, status = Open3.capture3(
      env,
      "ruby", EXPORT_SCRIPT.to_s, content.to_s, out.to_s,
      chdir: REPO_ROOT.to_s
    )
    fail!("path-filter export failed:\n#{stderr}\n#{stdout}") unless status.success?

    stdout
  end

  run.call("")
  article_a = out.join("collections/articles/2026-08-22-filter-a.json")
  article_b = out.join("collections/articles/2026-08-22-filter-b.json")
  fail!("missing filter-a") unless article_a.file?
  fail!("missing filter-b") unless article_b.file?

  b_mtime = article_b.mtime
  b_body = article_b.read
  index_before = out.join("data/writing_index.json").read
  sleep 1

  write_article.call("filter-a", "Second A — path filter should rebuild this one")
  filtered = run.call("content/collections/articles/filter-a.md")
  fail!("path-filter export should reuse unchanged files") unless filtered.match?(/unchanged=[1-9]/)

  fail!("unchanged B was rewritten") unless article_b.mtime == b_mtime
  fail!("unchanged B bytes changed") unless article_b.read == b_body
  fail!("changed A was not rewritten") if article_a.read == "First A"
  fail!("changed A body missing") unless article_a.read.include?("Second A")

  index_after = out.join("data/writing_index.json").read
  fail!("writing_index must rebuild when an article changes") if index_after == index_before
  fail!("manifest missing after path-filter export") unless out.join("manifest.json").file?

  WritingIndexContract.assert_slugs_match_export!(out)

  puts "Export path-filter OK (B mtime preserved, A + writing_index rebuilt)"
end

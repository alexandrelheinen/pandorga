#!/usr/bin/env ruby
# frozen_string_literal: true

# Checksum skip planner for R2 JSON publish. No live credentials.

$stdout.sync = true
$stderr.sync = true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

require_relative "../lib/r2_json_sync"
require_relative "../lib/writing_index_contract"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_SCRIPT = REPO_ROOT.join("scripts/content/export-content-json.rb")

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

def md5(text)
  Digest::MD5.hexdigest(text)
end

puts "Testing R2 JSON checksum skip planner..."

check!(!R2JsonSync.skip_upload?(nil, "abc"), "missing etag must upload")
check!(!R2JsonSync.skip_upload?("", "abc"), "blank etag must upload")
check!(!R2JsonSync.skip_upload?("abc-2", "abc"), "multipart etag must upload")
check!(!R2JsonSync.skip_upload?('"abc-2"', "abc"), "quoted multipart etag must upload")
check!(R2JsonSync.skip_upload?("abc", "abc"), "matching md5 must skip")
check!(R2JsonSync.skip_upload?("ABC", "abc"), "etag compare is case-insensitive")
check!(R2JsonSync.skip_upload?('"abc"', "abc"), "quoted etag must still skip")
check!(!R2JsonSync.skip_upload?("abc", "def"), "hash mismatch must upload")
check!(
  !R2JsonSync.skip_upload?("abc", "abc", key: "data/writing_index.json"),
  "writing_index.json must always upload"
)

listed = R2JsonSync.contents_to_etags([
  { "Key" => "collections/articles/a.json", "ETag" => '"aaa"' },
  { "Key" => "collections/", "ETag" => '"dir"' },
  { "Key" => "", "ETag" => '"empty"' }
])
check!(listed == { "collections/articles/a.json" => "aaa" }, "list contents keep file keys only")

plan = R2JsonSync.plan(
  [
    { "key" => "collections/articles/a.json", "md5" => "aaa" },
    { "key" => "collections/articles/b.json", "md5" => "bbb" },
    { "key" => "data/writing_index.json", "md5" => "idx" }
  ],
  {
    "collections/articles/a.json" => "aaa",
    "collections/articles/b.json" => "old-b",
    "collections/articles/gone.json" => "zzz",
    "data/writing_index.json" => "idx"
  }
)
check!(plan["upload"] == ["collections/articles/b.json", "data/writing_index.json"],
       "mismatch + writing_index upload (got #{plan['upload'].inspect})")
check!(plan["skip"] == ["collections/articles/a.json"], "unchanged A must skip (got #{plan['skip'].inspect})")
check!(plan["delete"] == ["collections/articles/gone.json"], "extra remote key must delete")

summary = R2JsonSync.summary_line("collections", plan)
check!(summary.include?("uploaded=2"), "summary uploaded count (#{summary})")
check!(summary.include?("skipped=1"), "summary skipped count (#{summary})")
check!(summary.include?("deleted=1"), "summary deleted count (#{summary})")

puts "  planner OK"

puts "Testing export A → sync → change A → incremental export → small upload..."

Dir.mktmpdir("r2-json-sync-") do |dir|
  root = Pathname.new(dir)
  content = root.join("content")
  export = root.join("export")
  FileUtils.mkdir_p(content.join("collections/articles"))

  write_article = lambda do |stem, title, body|
    content.join("collections/articles/#{stem}.md").write(<<~MARKDOWN)
      ---
      title: #{title}
      key: #{stem}
      date: 2026-08-22
      published: true
      ---
      #{body}
    MARKDOWN
  end

  write_article.call("article-a", "Article A", "Body A version one.")
  write_article.call("article-b", "Article B", "Body B stays put.")
  %w[article-c article-d article-e article-f].each do |stem|
    write_article.call(stem, stem, "Unchanged body for #{stem}.")
  end

  run_export = lambda do |changed_paths|
    env = {
      "CONTENT_API_BASE_URL" => "",
      "CONTENT_EXPORT_SKIP_VALIDATE" => "1"
    }
    env["CONTENT_EXPORT_CHANGED_PATHS"] = changed_paths.join("\n") unless changed_paths.empty?
    stdout, stderr, status = Open3.capture3(
      env,
      "ruby", EXPORT_SCRIPT.to_s, content.to_s, export.to_s,
      chdir: REPO_ROOT.to_s
    )
    fail!("export failed:\n#{stderr}\n#{stdout}") unless status.success?

    stdout
  end

  first = run_export.call([])
  check!(first.include?("changed="), "first export missing write summary")

  a_path = export.join("collections/articles/2026-08-22-article-a.json")
  b_path = export.join("collections/articles/2026-08-22-article-b.json")
  check!(a_path.file?, "missing exported A")
  check!(b_path.file?, "missing exported B")

  remote = {}
  apply_plan = lambda do |planned|
    planned["upload"].each do |key|
      local = export.join(key)
      body = local.binread
      remote[key] = { "body" => body, "etag" => md5(body) }
    end
    planned["delete"].each { |key| remote.delete(key) }
  end

  local_files = lambda do
    export.find.select(&:file?).filter_map do |path|
      rel = path.relative_path_from(export).to_s
      next if rel == "manifest.json"

      { "key" => rel, "md5" => md5(path.binread) }
    end
  end

  first_plan = R2JsonSync.plan(local_files.call, {})
  check!(first_plan["skip"].empty?, "empty remote must upload everything")
  apply_plan.call(first_plan)
  remote_b_before = remote["collections/articles/2026-08-22-article-b.json"]["body"]

  write_article.call("article-a", "Article A", "Body A version two — only this file changed.")
  sleep 1
  second = run_export.call(["content/collections/articles/article-a.md"])
  check!(second.match?(/unchanged=[1-9]/), "incremental re-export should reuse B (#{second})")

  check!(b_path.binread == remote_b_before,
         "incremental export must leave B bytes unchanged")

  second_plan = R2JsonSync.plan(
    local_files.call,
    remote.transform_values { |item| item["etag"] }
  )
  uploaded = second_plan["upload"]
  skipped = second_plan["skip"]
  check!(uploaded.length < skipped.length,
         "second sync should upload fewer than it skips (upload=#{uploaded.length} skip=#{skipped.length} upload=#{uploaded.inspect})")
  check!(uploaded.include?("collections/articles/2026-08-22-article-a.json"),
         "changed A must upload")
  check!(uploaded.include?("data/writing_index.json"),
         "writing_index must upload after A changes")
  check!(!uploaded.include?("collections/articles/2026-08-22-article-b.json"),
         "unchanged B must not upload")
  check!(skipped.include?("collections/articles/2026-08-22-article-b.json"),
         "unchanged B must be skipped")

  apply_plan.call(second_plan)
  check!(remote["collections/articles/2026-08-22-article-b.json"]["body"] == remote_b_before,
         "remote B body must stay unchanged")

  WritingIndexContract.assert_slugs_match_export!(export)
  index = JSON.parse(export.join("data/writing_index.json").read)
  a_entry = index.find { |entry| entry["key"] == "article-a" }
  check!(!a_entry.nil?, "writing_index must include article-a")
  check!(export.join("collections/articles/#{a_entry['slug']}.json").file?,
         "Freshy-like dated slug must match an exported JSON file")
end

puts "R2 JSON sync skip logic OK"

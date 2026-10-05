#!/usr/bin/env ruby
# frozen_string_literal: true

# Incremental JSON prefix sync to Cloudflare R2.
# Skip aws s3 cp when list-objects-v2 ETag is a single-part MD5 equal to the
# local file (case-insensitive). Upload if missing, ETag blank, multipart
# ("-" in ETag), or hash mismatch. Delete remote keys absent locally.
# Stale bodies cannot survive: mismatch still uploads and extras still delete.
# writing_index.json is always PUT so listings match the live object set.
#
# Usage:
#   sync-content-json-to-r2.rb <export_root> <prefix>
# Example:
#   sync-content-json-to-r2.rb _content_json collections

require "digest"
require "json"
require "open3"
require "pathname"
require "set"

require_relative "../lib/r2_json_sync"
require_relative "../lib/withdrawn_public_objects"

$stdout.sync = true
$stderr.sync = true

EXPORT_ROOT = Pathname.new(ARGV[0] || "_content_json").expand_path
PREFIX = (ARGV[1] || "").sub(%r{\A/+}, "").sub(%r{/+\z}, "")

def fail!(message)
  warn message
  exit 1
end

fail!("Usage: #{$PROGRAM_NAME} <export_root> <prefix>") if PREFIX.empty?

endpoint = ENV["R2_ENDPOINT"].to_s
bucket = ENV["R2_BUCKET"].to_s
fail!("R2_ENDPOINT is required") if endpoint.empty?
fail!("R2_BUCKET is required") if bucket.empty?
fail!("aws CLI is required") if Open3.capture3("bash", "-lc", "command -v aws").last.exitstatus != 0

SRC = EXPORT_ROOT.join(PREFIX)
fail!("Missing local prefix directory: #{SRC}") unless SRC.directory?

CACHE_CONTROL = "public,max-age=60"

# The export is mostly JSON, and was entirely JSON until the home band plates
# started shipping as drawings. Serving an SVG as application/json costs nothing
# for a fetch that reads it as text, and everything for anything that does not.
CONTENT_TYPES = {
  ".json" => "application/json",
  ".svg" => "image/svg+xml"
}.freeze

def content_type_for(path)
  CONTENT_TYPES.fetch(path.extname.downcase) do
    fail!("no content type registered for #{path.extname} (#{path}); add one to CONTENT_TYPES")
  end
end

def run_aws(*args)
  cmd = ["aws", *args, "--endpoint-url", ENV.fetch("R2_ENDPOINT")]
  stdout, stderr, status = Open3.capture3(
    {
      "AWS_ACCESS_KEY_ID" => ENV.fetch("R2_ACCESS_KEY_ID"),
      "AWS_SECRET_ACCESS_KEY" => ENV.fetch("R2_SECRET_ACCESS_KEY"),
      "AWS_DEFAULT_REGION" => ENV.fetch("R2_REGION", "auto")
    },
    *cmd
  )
  [stdout, stderr, status]
end

def list_remote_objects(prefix)
  etags = {}
  token = nil
  loop do
    args = [
      "s3api", "list-objects-v2",
      "--bucket", ENV.fetch("R2_BUCKET"),
      "--prefix", "#{prefix}/",
      "--output", "json"
    ]
    args += ["--continuation-token", token] if token
    stdout, stderr, status = run_aws(*args)
    fail!("list-objects-v2 failed for #{prefix}/: #{stderr}") unless status.success?

    payload = stdout.strip.empty? ? {} : JSON.parse(stdout)
    etags.merge!(R2JsonSync.contents_to_etags(payload["Contents"]))
    break unless payload["IsTruncated"]

    token = payload["NextContinuationToken"]
    fail!("list-objects-v2 truncated without continuation token") if token.to_s.empty?
  end
  etags
end

def local_md5(path)
  Digest::MD5.hexdigest(path.binread)
end

local_files = SRC.find.select(&:file?).map do |path|
  rel = path.relative_path_from(SRC).to_s
  key = "#{PREFIX}/#{rel}"
  [path, key, local_md5(path)]
end

remote_etags = list_remote_objects(PREFIX)
plan = R2JsonSync.plan(
  local_files.map { |(_path, key, md5)| { "key" => key, "md5" => md5 } },
  remote_etags
)
upload_keys = plan["upload"].to_set

uploaded = 0
local_files.each do |path, key, _md5|
  next unless upload_keys.include?(key)

  _stdout, stderr, status = run_aws(
    "s3", "cp", path.to_s, "s3://#{ENV.fetch('R2_BUCKET')}/#{key}",
    "--cache-control", CACHE_CONTROL,
    "--content-type", content_type_for(path)
  )
  fail!("upload failed for #{key}: #{stderr}") unless status.success?

  uploaded += 1
end

deleted = 0
plan["delete"].each do |key|
  _stdout, stderr, status = run_aws(
    "s3", "rm", "s3://#{ENV.fetch('R2_BUCKET')}/#{key}"
  )
  fail!("delete failed for #{key}: #{stderr}") unless status.success?

  deleted += 1
end

skipped = plan["skip"].length
local_keys = local_files.map { |(_, key, _)| key }.to_set

remote_after = list_remote_objects(PREFIX)
extra = (remote_after.keys.to_set - local_keys).to_a.sort
missing = (local_keys - remote_after.keys.to_set).to_a.sort
unless extra.empty? && missing.empty?
  fail!("R2 keyset drift for #{PREFIX}/ extra=#{extra.inspect} missing=#{missing.inspect}")
end

local_files.each do |_path, key, md5|
  etag = remote_after[key].to_s
  next if R2JsonSync.multipart_etag?(etag)

  unless etag.casecmp?(md5)
    fail!("R2 origin mismatch for #{key}: etag=#{etag.inspect} md5=#{md5.inspect}")
  end
end

WithdrawnPublicObjects::EXPORT_PATHS.each do |relative|
  next unless relative.start_with?("#{PREFIX}/")
  next unless remote_after.key?(relative)

  fail!("withdrawn object still present on R2: #{relative}")
end

puts "R2 replace sync #{PREFIX}/: uploaded=#{uploaded} skipped=#{skipped} deleted=#{deleted}"

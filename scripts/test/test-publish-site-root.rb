#!/usr/bin/env ruby
# frozen_string_literal: true

# Refs: media sync must not silently use the gem tree as SITE_ROOT.
require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
SCRIPT = ROOT.join("scripts/content/publish-content-to-object-store.sh")

def fail!(message)
  warn "FAIL test-publish-site-root: #{message}"
  exit 1
end

fail!("missing #{SCRIPT}") unless SCRIPT.file?

env = ENV.to_h
env.delete("PANDORGA_SITE_ROOT")
# Avoid falling through to real credentials if a developer has them set.
%w[
  S3_ENDPOINT S3_BUCKET S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY
  R2_ENDPOINT R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY
].each { |key| env.delete(key) }

out, status = Open3.capture2e(env, "bash", SCRIPT.to_s)
fail!("expected exit 1 without PANDORGA_SITE_ROOT, got #{status.exitstatus}") unless status.exitstatus == 1
fail!("expected PANDORGA_SITE_ROOT error, got:\n#{out}") unless out.include?("PANDORGA_SITE_ROOT must be set")

ok_env = env.merge(
  "PANDORGA_SITE_ROOT" => ROOT.join("examples/minimal").to_s,
  "S3_ENDPOINT" => "https://example.invalid",
  "S3_BUCKET" => "test-bucket",
  "S3_ACCESS_KEY_ID" => "test",
  "S3_SECRET_ACCESS_KEY" => "test"
)
out2, status2 = Open3.capture2e(ok_env, "bash", SCRIPT.to_s, ROOT.join("examples/minimal/_content_json").to_s)
fail!("with PANDORGA_SITE_ROOT set, must not fail the site-root guard; got #{status2.exitstatus}:\n#{out2}") if out2.include?("PANDORGA_SITE_ROOT must be set")

puts "PASS test-publish-site-root"

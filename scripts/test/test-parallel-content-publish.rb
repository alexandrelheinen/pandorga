#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-53: the object-store publish runs its prefix syncs in parallel and
# uploads manifest.json last, only when every job succeeded. Uses a stateful
# fake `aws` on PATH; no credentials or network.

$stdout.sync = true
$stderr.sync = true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("../..").expand_path
SCRIPT = ROOT.join("scripts/content/publish-content-to-object-store.sh")
SYNC = ROOT.join("scripts/content/sync-content-json-to-r2.rb")

def fail!(message)
  warn "FAIL test-parallel-content-publish: #{message}"
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

# The fake keeps bucket objects under $FAKE_AWS_BUCKET_DIR and appends one
# JSON line per call ({argv, start, end}) to $FAKE_AWS_LOG. Listing sleeps so
# overlapping prefix syncs are observable. FAKE_AWS_FAIL_PREFIX makes the
# listing of that prefix fail.
FAKE_AWS = <<~'RUBY'
  #!/usr/bin/env ruby
  require "digest"
  require "fileutils"
  require "json"
  bucket_dir = ENV.fetch("FAKE_AWS_BUCKET_DIR")
  start = Process.clock_gettime(Process::CLOCK_REALTIME)
  args = ARGV.dup
  status = 0
  key_of = ->(url) { url.sub(%r{\As3://[^/]+/?}, "") }
  opt = ->(name) { (i = args.index(name)) ? args[i + 1] : nil }
  case args[0, 2]
  when %w[s3api list-objects-v2]
    prefix = opt.call("--prefix").to_s
    sleep 0.4
    if (bad = ENV["FAKE_AWS_FAIL_PREFIX"].to_s) != "" && prefix == "#{bad}/"
      warn "fake aws: listing #{prefix} failed"
      status = 1
    else
      contents = Dir.glob(File.join(bucket_dir, "**", "*")).select { |f| File.file?(f) }.map do |f|
        key = f.delete_prefix("#{bucket_dir}/")
        next unless key.start_with?(prefix)
        { "Key" => key, "ETag" => "\"#{Digest::MD5.file(f).hexdigest}\"" }
      end.compact
      puts JSON.generate({ "Contents" => contents, "IsTruncated" => false })
    end
  when %w[s3 cp]
    dest = File.join(bucket_dir, key_of.call(args[3]))
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(args[2], dest)
  when %w[s3 rm]
    FileUtils.rm_f(File.join(bucket_dir, key_of.call(args[2])))
  when %w[s3 sync]
    src = args[2]
    prefix = key_of.call(args[3])
    local = Dir.glob(File.join(src, "**", "*")).select { |f| File.file?(f) }.map { |f| f.delete_prefix("#{src}/") }
    local.each do |rel|
      dest = File.join(bucket_dir, prefix, rel)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(File.join(src, rel), dest)
    end
    if args.include?("--delete")
      Dir.glob(File.join(bucket_dir, prefix, "**", "*")).select { |f| File.file?(f) }.each do |f|
        FileUtils.rm_f(f) unless local.include?(f.delete_prefix("#{File.join(bucket_dir, prefix)}/"))
      end
    end
  else
    warn "fake aws: unsupported #{args.inspect}"
    status = 2
  end
  finish = Process.clock_gettime(Process::CLOCK_REALTIME)
  File.open(ENV.fetch("FAKE_AWS_LOG"), "a") { |io| io.puts(JSON.generate({ "argv" => args, "start" => start, "end" => finish })) }
  exit status
RUBY

check!(SCRIPT.file?, "missing #{SCRIPT}")
check!(!File.read(SYNC).include?("bash\", \"-lc\""),
       "sync-content-json-to-r2.rb must check for aws on its own PATH, not a login shell's")

def write(path, body)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, body)
end

def run_publish(tmp, fail_prefix: nil)
  site = File.join(tmp, "site")
  export = File.join(site, "_content_json")
  bucket = File.join(tmp, "bucket")
  bin = File.join(tmp, "bin")
  log = File.join(tmp, "aws.log")
  FileUtils.rm_rf([bucket, log])
  write(File.join(export, "collections/articles/a.json"), %({"a":1}\n))
  write(File.join(export, "data/b.json"), %({"b":1}\n))
  write(File.join(export, "pages/c.json"), %({"c":1}\n))
  write(File.join(export, "manifest.json"), %({"version":1}\n))
  write(File.join(site, "content/media/images/x.png"), "png")
  write(File.join(bucket, "collections/articles/stale.json"), "{}")
  write(File.join(bucket, "media/old.png"), "old")
  write(File.join(bin, "aws"), FAKE_AWS)
  FileUtils.chmod(0o755, File.join(bin, "aws"))

  env = ENV.to_h.reject { |k, _| k.start_with?("S3_", "R2_", "AWS_") }.merge(
    "PATH" => "#{bin}:#{ENV.fetch('PATH')}",
    "PANDORGA_SITE_ROOT" => site,
    "S3_ENDPOINT" => "https://example.invalid",
    "S3_BUCKET" => "test-bucket",
    "S3_ACCESS_KEY_ID" => "test",
    "S3_SECRET_ACCESS_KEY" => "test",
    "FAKE_AWS_BUCKET_DIR" => bucket,
    "FAKE_AWS_LOG" => log
  )
  env["FAKE_AWS_FAIL_PREFIX"] = fail_prefix if fail_prefix
  out, status = Open3.capture2e(env, "bash", SCRIPT.to_s, export)
  calls = File.file?(log) ? File.readlines(log).map { |l| JSON.parse(l) } : []
  [out, status, calls, bucket]
end

Dir.mktmpdir("pandorga-parallel-publish") do |tmp|
  out, status, calls, bucket = run_publish(tmp)
  check!(status.success?, "publish failed (#{status.exitstatus}):\n#{out}")

  objects = Dir.glob(File.join(bucket, "**", "*")).select { |f| File.file?(f) }
               .map { |f| f.delete_prefix("#{bucket}/") }.sort
  expected = %w[collections/articles/a.json data/b.json manifest.json media/images/x.png pages/c.json]
  check!(objects == expected, "bucket objects #{objects.inspect}, expected #{expected.inspect}")

  first_list = %w[collections data pages].to_h do |prefix|
    call = calls.find { |c| c["argv"][0, 2] == %w[s3api list-objects-v2] && c["argv"].include?("#{prefix}/") }
    check!(call, "no listing of #{prefix}/ in #{calls.map { |c| c['argv'].first(2) }.inspect}")
    [prefix, call]
  end
  latest_start = first_list.values.map { |c| c["start"] }.max
  earliest_end = first_list.values.map { |c| c["end"] }.min
  check!(latest_start < earliest_end,
         "collections/, data/ and pages/ syncs did not overlap; they must run in parallel")

  manifest = calls.select { |c| c["argv"][0, 2] == %w[s3 cp] && c["argv"][3].to_s.end_with?("/manifest.json") }
  check!(manifest.length == 1, "expected one manifest upload, got #{manifest.length}")
  others = calls - manifest
  check!(others.all? { |c| c["end"] <= manifest.first["start"] },
         "manifest.json must be uploaded after every other call ended")

  order = ["R2 replace sync collections/", "R2 replace sync data/", "R2 replace sync pages/",
           "==> Sync media/", "==> Upload manifest.json", "==> Object-store publish complete"]
  positions = order.map { |marker| out.index(marker) }
  check!(positions.none?(&:nil?), "missing log markers #{order.zip(positions).select { |_, p| p.nil? }.map(&:first)}:\n#{out}")
  check!(positions == positions.sort, "job logs must print in the fixed order #{order.inspect}:\n#{out}")

  out, status, calls, = run_publish(tmp, fail_prefix: "data")
  check!(!status.success?, "publish must fail when a prefix sync fails:\n#{out}")
  check!(out.include?("listing data/ failed") || out.include?("list-objects-v2 failed for data/"),
         "the failed job's log must be printed:\n#{out}")
  check!(out.include?("data"), "the failure must name the failed job")
  check!(calls.none? { |c| c["argv"][0, 2] == %w[s3 cp] && c["argv"][3].to_s.end_with?("/manifest.json") },
         "manifest.json must not be uploaded when a job failed")
end

puts "PASS test-parallel-content-publish"

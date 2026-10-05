# frozen_string_literal: true

# Refs: PLT-0.2
require "pathname"
require "open3"
require "fileutils"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")
DEST = ROOT.join("tmp/install-functions-test")

FileUtils.rm_rf(DEST)
DEST.mkpath
env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
stdout, stderr, status = Open3.capture3(env, "ruby", EXE.to_s, "install-functions", DEST.to_s)
unless status.success?
  warn "FAIL test-install-functions: #{stdout}\n#{stderr}"
  exit 1
end

api = DEST.join("functions/api/studio/[[path]].js")
unless api.file?
  warn "FAIL test-install-functions: functions not copied"
  exit 1
end
stamp = DEST.join("functions/.pandorga-version")
unless stamp.file? && stamp.read.match?(/\d+\.\d+\.\d+/)
  warn "FAIL test-install-functions: version stamp missing"
  exit 1
end
# Must not embed a default owner repo in the stub.
body = api.read
owner_slug = %w[alexandre lheinen].join
if body.include?(owner_slug)
  warn "FAIL test-install-functions: personal data in functions stub"
  exit 1
end

puts "PASS test-install-functions"

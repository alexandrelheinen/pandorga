# frozen_string_literal: true

# Refs: PLT-0.3, PLT-AC-5
require "pathname"
require "open3"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXAMPLE = ROOT.join("examples/minimal")
EXE = ROOT.join("exe/pandorga")

def run_doctor(dir)
  env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
  Open3.capture3(env, "ruby", EXE.to_s, "doctor", dir.to_s)
end

stdout, stderr, status = run_doctor(EXAMPLE)
unless status.success?
  warn "FAIL test-doctor: expected exit 0\n#{stdout}\n#{stderr}"
  exit 1
end
unless stdout.include?("pandorga doctor: ok")
  warn "FAIL test-doctor: unexpected stdout:\n#{stdout}"
  exit 1
end

bad = ROOT.join("tmp/doctor-bad-fixture")
bad.mkpath
bad.join("_config.yml").write("title: x\n")
_out, err, st = run_doctor(bad)
if st.success?
  warn "FAIL test-doctor: expected failure without pandorga: key"
  exit 1
end
unless err.include?("pandorga:")
  warn "FAIL test-doctor: expected error about pandorga: key\n#{err}"
  exit 1
end

puts "PASS test-doctor"

# frozen_string_literal: true

# Refs: PLT Phase 6 — pandorga new
require "pathname"
require "open3"
require "fileutils"
require "yaml"
require "date"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")
DEST = ROOT.join("tmp/new-site-test")

def run_new(*args)
  env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
  Open3.capture3(env, "ruby", EXE.to_s, "new", *args)
end

def run_doctor(dir)
  env = { "RUBYOPT" => "-I#{ROOT.join('lib')}" }
  Open3.capture3(env, "ruby", EXE.to_s, "doctor", dir.to_s)
end

guide = ROOT.join("docs/getting-started.md").read
readme = ROOT.join("README.md").read
unless guide.include?('gem at `~> 1.3`')
  warn "FAIL test-new: getting-started must document the scaffold pin ~> 1.3"
  exit 1
end
if readme.include?("once 1.1 is on RubyGems")
  warn "FAIL test-new: README still says the gem is unpublished at 1.1"
  exit 1
end

FileUtils.rm_rf(DEST)

stdout, stderr, status = run_new(DEST.to_s)
unless status.success?
  warn "FAIL test-new: expected exit 0\n#{stdout}\n#{stderr}"
  exit 1
end
unless stdout.include?("Created site at") && stdout.include?("bundle install")
  warn "FAIL test-new: missing next-steps output\n#{stdout}"
  exit 1
end

required = %w[
  _config.yml
  Gemfile
  index.html
  _redirects
  content/pages/headers.yml
  content/collections/articles/2026-01-01-hello.md
  content/collections/articles/2026-01-02-second.md
]
required.each do |rel|
  unless DEST.join(rel).file?
    warn "FAIL test-new: missing #{rel}"
    exit 1
  end
end

%w[Gemfile.lock _site vendor .bundle _content_json .jekyll-cache].each do |name|
  if DEST.join(name).exist?
    warn "FAIL test-new: should exclude #{name}"
    exit 1
  end
end

gemfile = DEST.join("Gemfile").read
unless gemfile.include?('gem "pandorga", "~> 1.3"')
  warn "FAIL test-new: Gemfile must pin pandorga ~> 1.3\n#{gemfile}"
  exit 1
end
unless gemfile.include?("path:") && gemfile.include?("github:")
  warn "FAIL test-new: Gemfile should comment path/github fallbacks"
  exit 1
end

config = YAML.safe_load(DEST.join("_config.yml").read, permitted_classes: [Date]) || {}
pandorga = config["pandorga"]
unless pandorga.is_a?(Hash)
  warn "FAIL test-new: missing pandorga: in _config.yml"
  exit 1
end
identity = pandorga["identity"]
unless identity.is_a?(Hash) && identity["name"].to_s == "Ada Example"
  warn "FAIL test-new: expected Ada Example identity"
  exit 1
end
backend = pandorga.dig("content", "backend")
unless backend == "static"
  warn "FAIL test-new: expected content.backend: static, got #{backend.inspect}"
  exit 1
end
pages = pandorga["pages"]
unless pages.is_a?(Array) && pages.any?
  warn "FAIL test-new: expected pandorga.pages entries"
  exit 1
end

dout, derr, dstatus = run_doctor(DEST)
unless dstatus.success? && dout.include?("pandorga doctor: ok")
  warn "FAIL test-new: doctor failed on scaffold\n#{dout}\n#{derr}"
  exit 1
end

_out, err, st = run_new(DEST.to_s)
if st.success?
  warn "FAIL test-new: expected failure without --force on nonempty dir"
  exit 1
end
unless err.include?("--force")
  warn "FAIL test-new: expected --force hint\n#{err}"
  exit 1
end

stdout2, stderr2, status2 = run_new(DEST.to_s, "--force")
unless status2.success?
  warn "FAIL test-new: --force should succeed\n#{stdout2}\n#{stderr2}"
  exit 1
end

puts "PASS test-new"

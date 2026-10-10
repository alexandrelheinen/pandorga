# frozen_string_literal: true

# Refs: PLT-AC-6 — examples build with the static backend and fictional persona.
require "pathname"
require "open3"
require "fileutils"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")

def run!(*cmd, chdir:)
  env = {
    "RUBYOPT" => "-I#{ROOT.join('lib')}",
    "PANDORGA_SITE_ROOT" => chdir.to_s,
    "CONTENT_API_BASE_URL" => "",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1",
    "JEKYLL_ENV" => "production"
  }
  stdout, stderr, status = Open3.capture3(env, *cmd, chdir: chdir.to_s)
  return [stdout, stderr] if status.success?

  warn "FAIL test-examples-build: #{cmd.join(' ')} (cwd=#{chdir})\n#{stdout}\n#{stderr}"
  exit 1
end

%w[minimal full].each do |name|
  example = ROOT.join("examples", name)
  unless example.join("_config.yml").file?
    warn "FAIL test-examples-build: missing #{example}"
    exit 1
  end

  FileUtils.rm_rf(example.join("_site"))
  FileUtils.rm_rf(example.join("_content_json"))

  run!("bundle", "install", "--quiet", chdir: example) if example.join("Gemfile").file?
  run!("ruby", EXE.to_s, "export", "content", "_content_json", chdir: example)
  run!("bundle", "exec", "jekyll", "build", "--quiet", chdir: example)

  index = example.join("_site/index.html")
  unless index.file?
    warn "FAIL test-examples-build: #{name} missing _site/index.html"
    exit 1
  end
  html = index.read
  if html.match?(/Alexandre L\. Heinen|Loeblein Heinen/i)
    warn "FAIL test-examples-build: #{name} home HTML leaked owner identity"
    exit 1
  end
  if html.include?("Ada Example") == false && name == "full"
    warn "FAIL test-examples-build: full example missing fictional persona"
    exit 1
  end
  unless html.include?("home-hero") || html.include?("home-ledger")
    warn "FAIL test-examples-build: #{name} home layout missing"
    exit 1
  end
  origin = name == "full" ? "https://example.org" : "https://example.com"
  sitemap = example.join("_site/sitemap.xml").read
  robots = example.join("_site/robots.txt").read
  unless sitemap.include?("<loc>#{origin}/</loc>") || sitemap.include?("<loc>#{origin}/index.html</loc>")
    warn "FAIL test-examples-build: #{name} sitemap missing the home URL\n#{sitemap}"
    exit 1
  end
  unless robots.include?("Sitemap: #{origin}/sitemap.xml")
    warn "FAIL test-examples-build: #{name} robots missing the sitemap line\n#{robots}"
    exit 1
  end
  unless html.include?('application/ld+json') && html.include?('"@type": "Person"')
    warn "FAIL test-examples-build: #{name} home is missing JSON-LD"
    exit 1
  end
end

puts "PASS test-examples-build"

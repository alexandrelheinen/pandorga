# frozen_string_literal: true

# Refs: PLT-AC-42 — home listing bands emit kicker, title, and note slots in both normal and agnostic builds.
require "pathname"
require "open3"
require "fileutils"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXE = ROOT.join("exe/pandorga")
EXAMPLE = ROOT.join("examples/full")

def fail!(message)
  warn "FAIL test-home-band-intro: #{message}"
  exit 1
end

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

  fail!("#{cmd.join(' ')} (cwd=#{chdir})\n#{stdout}\n#{stderr}")
end

def listing_sections(html)
  sections = []
  html.scan(/<section\b[^>]*\bdata-home-kind="([^"]+)"[^>]*>.*?<\/section>/m) do
    section = Regexp.last_match(0)
    kind = Regexp.last_match(1)
    next if kind == "index"

    key = section[/\bdata-home-key="([^"]+)"/, 1] || kind
    banner_idx = section.index('data-content-home-section="')
    fail!("section #{key} missing data-content-home-section") unless banner_idx

    sections << [key, section[banner_idx..]]
  end
  sections
end

run!("bundle", "install", "--quiet", chdir: EXAMPLE) if EXAMPLE.join("Gemfile").file?
run!("ruby", EXE.to_s, "export", "content", "_content_json", chdir: EXAMPLE)

Dir.mktmpdir("pandorga-home-band-normal-") do |normal_dir|
  run!("bundle", "exec", "jekyll", "build", "--quiet", "-d", normal_dir, chdir: EXAMPLE)
  html = File.read(File.join(normal_dir, "index.html"))
  sections = listing_sections(html)
  fail!("normal build produced no listing sections") if sections.empty?

  sections.each do |key, slice|
    %w[data-content-section-kicker data-content-section-title data-content-section-note].each do |attr|
      fail!("normal build band #{key} missing #{attr}") unless slice.include?(attr)
    end
  end

  projects = sections.assoc("projects")&.last
  fail!("normal build missing projects band") unless projects
  unless projects.include?("Portfolio systems in the full example.")
    fail!("normal build projects band missing note text from headers.yml")
  end
end

Dir.mktmpdir("pandorga-home-band-agnostic-") do |agnostic_dir|
  agnostic_cfg = File.join(agnostic_dir, "agnostic.yml")
  File.write(agnostic_cfg, "shell_content_agnostic: true\n")
  out_dir = File.join(agnostic_dir, "site")
  run!(
    "bundle", "exec", "jekyll", "build", "--quiet",
    "--config", "_config.yml,#{agnostic_cfg}",
    "-d", out_dir,
    chdir: EXAMPLE
  )
  html = File.read(File.join(out_dir, "index.html"))
  sections = listing_sections(html)
  fail!("agnostic build produced no listing sections") if sections.empty?

  sections.each do |key, slice|
    %w[data-content-section-kicker data-content-section-title data-content-section-note].each do |attr|
      fail!("agnostic build band #{key} missing #{attr}") unless slice.include?(attr)
    end
  end

  projects = sections.assoc("projects")&.last
  fail!("agnostic build missing projects band") unless projects
  unless projects.include?("data-content-section-note></p>")
    fail!("agnostic build projects band note slot is not empty")
  end
end

puts "PASS test-home-band-intro"

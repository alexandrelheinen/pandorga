#!/usr/bin/env ruby
# frozen_string_literal: true

# Public content-store contract: print-only CV copy stays in Git for private
# PDF builds and must not appear in the R2 JSON export.
# Spec: docs/content/architecture.md

$stdout.sync = true
$stderr.sync = true

require "date"
require "json"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
EXPORT_SCRIPT = REPO_ROOT.join("scripts/content/export-content-json.rb")
JOBS_DIR = REPO_ROOT.join("content/collections/jobs")

PRIVATE_JOB_FIELDS = %w[body_extended body_single_page].freeze
PRINT_ONLY_PAGE_FRAGMENTS = %w[
  pages/cv/summary-extended.json
  pages/cv/summary-single-page.json
  pages/cv/ai-practice.json
].freeze

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
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

def split_front_matter(text)
  text = text.sub(/\A\xEF\xBB\xBF/, "")
  return [{}, text] unless text.start_with?("---\n")

  parts = text.split(/^---\s*$\n?/, 3)
  return [{}, text] unless parts.length == 3

  data = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
  [data, parts[2]]
end

puts "Testing public CV export redaction..."

source_jobs = JOBS_DIR.glob("*.md")
check!(!source_jobs.empty?, "expected job Markdown under content/collections/jobs")

jobs_with_private = source_jobs.select do |path|
  front_matter, = split_front_matter(path.read)
  PRIVATE_JOB_FIELDS.any? { |field| !front_matter[field].to_s.strip.empty? }
end
check!(!jobs_with_private.empty?, "expected at least one job with body_extended or body_single_page in Git")

extended_summary = REPO_ROOT.join("content/pages/cv/summary-extended.md")
single_page_summary = REPO_ROOT.join("content/pages/cv/summary-single-page.md")
check!(extended_summary.file?, "missing print-only #{extended_summary}")
check!(single_page_summary.file?, "missing print-only #{single_page_summary}")

def check_export!(out, jobs_with_private)
  job_json = out.glob("collections/jobs/*.json")
  check!(!job_json.empty?, "export produced no job JSON")

  job_json.each do |path|
    payload = JSON.parse(path.read)
    front_matter = payload["front_matter"] || {}
    PRIVATE_JOB_FIELDS.each do |field|
      check!(
        !front_matter.key?(field),
        "#{path.basename} public JSON still contains front_matter.#{field}"
      )
    end

    source = JOBS_DIR.join("#{path.basename('.json')}.md")
    next unless source.file?

    source_fm, = split_front_matter(source.read)
    next if source_fm["body_public"].to_s.strip.empty?

    check!(
      !front_matter["body_public"].to_s.strip.empty?,
      "#{path.basename} dropped body_public while redacting print-only fields"
    )
  end

  PRINT_ONLY_PAGE_FRAGMENTS.each do |relative|
    leaked = out.join(relative)
    check!(!leaked.file?, "print-only fragment exported to public JSON: #{relative}")
  end

  public_summary = out.join("pages/cv/summary.json")
  check!(public_summary.file?, "public CV summary fragment missing from export")

  skills_json = out.join("data/skills.json")
  check!(!skills_json.file?, "skills.json should not be exported publicly (private CV PDF sidebar only)")

  contacts_json = out.join("data/contacts.json")
  check!(contacts_json.file?, "public contacts JSON missing from export")
  contacts = JSON.parse(contacts_json.read)
  check!(contacts.is_a?(Array) && !contacts.empty?, "public contacts JSON should be a non-empty array")
  contacts.each do |contact|
    href = contact.is_a?(Hash) ? contact["href"].to_s : ""
    check!(
      !href.start_with?("mailto:"),
      "data/contacts.json still exports a mailto contact (#{href})"
    )
  end
  check!(
    !contacts_json.read.match?(/mailto:|@gmail\.com/i),
    "data/contacts.json still contains a public email address"
  )

  print_header = REPO_ROOT.join("_includes/cv/cv-print-header.html")
  check!(print_header.file?, "missing private CV print header")
  check!(
    print_header.read.include?("mailto:"),
    "private CV print header must keep mailto for recruiter PDFs"
  )

  leaked_blob = out.glob("**/*.json").map(&:read).join("\n")
  jobs_with_private.each do |source|
    front_matter, = split_front_matter(source.read)
    PRIVATE_JOB_FIELDS.each do |field|
      snippet = front_matter[field].to_s.strip.lines.map(&:strip).reject(&:empty?).find { |line| line.length >= 40 }
      next if snippet.nil?

      check!(
        !leaked_blob.include?(snippet),
        "#{source.basename} #{field} still appears in public JSON (#{snippet[0, 80]}…)"
      )
    end
  end
end

existing = ARGV[0]
if existing
  out = Pathname.new(existing).expand_path
  check!(out.directory?, "export dir missing: #{out}")
  check_export!(out, jobs_with_private)
else
  Dir.mktmpdir("public-cv-export-") do |dir|
    out = Pathname.new(dir).join("export")
    run_export!(out)
    check_export!(out, jobs_with_private)
  end
end

puts "Public CV export redaction OK"

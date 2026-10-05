#!/usr/bin/env ruby
# frozen_string_literal: true

# Refs: PLT-AC-7
# CV collection fields outside the public allowlist must not enter export JSON.
# Uses a temp Ada Example fixture — no personal site data.

$stdout.sync = true
$stderr.sync = true

require "json"
require "open3"
require "pathname"
require "tmpdir"
require "fileutils"

ROOT = Pathname.new(__dir__).join("../..").expand_path
EXPORT_SCRIPT = ROOT.join("scripts/content/export-content-json.rb")

PRIVATE_SNIPPETS = [
  "PRIVATE_EXTENDED_JOB_BODY_MARKER_ada_example",
  "PRIVATE_SINGLE_PAGE_JOB_BODY_MARKER_ada_example",
  "PRIVATE_CONTACT_SECRET_ada@secret.example",
  "PRIVATE_EXTENDED_PRODUCT_BODY_MARKER_ada_example",
  "PRIVATE_PRODUCT_NOTES_ada_example"
].freeze

def fail!(message)
  warn "FAIL test-cv-export-contract: #{message}"
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

def write_site!(site)
  site.join("_config.yml").write(<<~YAML)
    title: "CV Export Contract Fixture"
    pandorga:
      identity:
        name: "Ada Example"
        short_name: "A. Example"
        url: "https://example.org"
        locale: en
      content:
        backend: static
        base_url: ""
      pages:
        - key: cv
          template: cv
          title: Curriculum Vitæ
          path: /pages/cv/
          collections: { jobs: jobs, products: products }
          home: { band: hero }
  YAML

  jobs = site.join("content/collections/jobs")
  products = site.join("content/collections/products")
  data = site.join("content/collections/data")
  FileUtils.mkdir_p([jobs, products, data])

  jobs.join("research-fellow.md").write(<<~MD)
    ---
    title: Research Fellow
    key: research-fellow
    company: Example Labs
    role: Research Fellow
    start: 2024-01
    end: 2026-06
    location: Example City
    summary: Fictional public CV entry for Ada Example.
    body_public: Public paragraph that may appear in the export.
    body_extended: |
      PRIVATE_EXTENDED_JOB_BODY_MARKER_ada_example
      Extended copy for private PDF builds only.
    body_single_page: |
      PRIVATE_SINGLE_PAGE_JOB_BODY_MARKER_ada_example
      Single-page private PDF copy.
    contact_email: PRIVATE_CONTACT_SECRET_ada@secret.example
    published: true
    ---

    Markdown body for Ada Example research role.
  MD

  products.join("ledger-tool.md").write(<<~MD)
    ---
    title: Ledger Tool
    key: ledger-tool
    product: Ledger Tool
    company: Example Labs
    body_extended: PRIVATE_EXTENDED_PRODUCT_BODY_MARKER_ada_example
    private_notes: PRIVATE_PRODUCT_NOTES_ada_example
    published: true
    ---

    Public product summary for Ada Example.
  MD

  # Public contacts only. Secrets belong on collection fields outside the
  # allowlist (contact_email above), not in committed public data files.
  data.join("contacts.yml").write(<<~YAML)
    - label: Example Org
      href: https://example.org
  YAML
end

def run_export!(site, out)
  env = {
    "PANDORGA_SITE_ROOT" => site.to_s,
    "CONTENT_API_BASE_URL" => "",
    "CONTENT_EXPORT_SKIP_VALIDATE" => "1",
    "RUBYOPT" => "-I#{ROOT.join('lib')}"
  }
  stdout, stderr, status = Open3.capture3(
    env,
    "ruby", EXPORT_SCRIPT.to_s, "content", out.to_s,
    chdir: site.to_s
  )
  fail!("export failed:\n#{stderr}\n#{stdout}") unless status.success?
end

puts "Testing CV export contract (PLT-AC-7)..."

Dir.mktmpdir("cv-export-contract-") do |dir|
  site = Pathname.new(dir).join("site")
  out = Pathname.new(dir).join("export")
  site.mkpath
  write_site!(site)
  run_export!(site, out)

  job_json = out.join("collections/jobs/research-fellow.json")
  product_json = out.join("collections/products/ledger-tool.json")
  check!(job_json.file?, "missing exported job JSON")
  check!(product_json.file?, "missing exported product JSON")

  job = JSON.parse(job_json.read)
  product = JSON.parse(product_json.read)
  job_fm = job["front_matter"] || {}
  product_fm = product["front_matter"] || {}

  %w[body_extended body_single_page contact_email].each do |field|
    check!(!job_fm.key?(field), "job front_matter still has #{field}")
  end
  check!(!job_fm["body_public"].to_s.strip.empty?, "job dropped body_public")

  %w[body_extended private_notes].each do |field|
    check!(!product_fm.key?(field), "product front_matter still has #{field}")
  end

  blob = out.glob("**/*").select(&:file?).map(&:read).join("\n")
  PRIVATE_SNIPPETS.each do |snippet|
    check!(!blob.include?(snippet), "private snippet leaked: #{snippet}")
  end
end

puts "PASS test-cv-export-contract"

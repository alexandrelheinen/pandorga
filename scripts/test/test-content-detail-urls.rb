#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

# End-to-end gate: editorial JSON export (storage contract) + shell detail URLs.
#
# Simulates CMS publish → R2 JSON → shell poster (HTML) → runtime JSON fetch.
# Fails if any published post/article would 404 at /posts/:slug/ or /articles/:slug/
# without a per-slug shell rebuild.
#
# Run via ./scripts/validate.sh and content-detail-url-gate.yml.

require "fileutils"
require "json"
require "net/http"
require "open3"
require "pathname"
require "socket"
require "tempfile"
require "timeout"

require_relative "../../_plugins/content_detail_paths"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CONTENT_ROOT = REPO_ROOT.join("content")
EXPORT_ROOT = REPO_ROOT.join("_content_json")
SITE_ROOT = REPO_ROOT.join("_site")
REDIRECTS_FILE = REPO_ROOT.join("_redirects")

SYNTHETIC_SLUG = "2099-01-01-ci-detail-url-gate"
SYNTHETIC_MARKER = "Synthetic post proving detail URLs work without a shell rebuild."

DETAIL_RUNTIME_MARKERS = [
  "ContentRuntime",
  "contentSlug",
  "loadCollection",
  "Skipping missing content object"
].freeze

def fail!(message)
  raise message
end

def check!(condition, message)
  fail!(message) unless condition
end

def run!(command, chdir: REPO_ROOT, env: {})
  stdout, stderr, status = Open3.capture3(env, *command, chdir: chdir.to_s)
  return [stdout, stderr] if status.success?

  fail!("Command failed (#{command.join(' ')}):\n#{stderr}\n#{stdout}")
end

def free_port
  server = TCPServer.new("127.0.0.1", 0)
  port = server.addr[1]
  server.close
  port
end

def validate_redirects!
  check!(REDIRECTS_FILE.file?, "Missing #{REDIRECTS_FILE}")

  text = REDIRECTS_FILE.read
  check!(text.include?("/posts/:slug #{ContentDetailPaths::POST_SHELL.rstrip} 200"),
         "_redirects must rewrite /posts/:slug/ to #{ContentDetailPaths::POST_SHELL}")
  check!(text.include?("/articles/:slug #{ContentDetailPaths::ARTICLE_SHELL.rstrip} 200"),
         "_redirects must rewrite /articles/:slug/ to #{ContentDetailPaths::ARTICLE_SHELL}")
  check!(text.include?("/products/:slug #{ContentDetailPaths::PRODUCT_SHELL.rstrip} 200"),
         "_redirects must rewrite /products/:slug/ to #{ContentDetailPaths::PRODUCT_SHELL}")
  check!(text.include?("/projects/:slug #{ContentDetailPaths::PROJECT_SHELL.rstrip} 200"),
         "_redirects must rewrite /projects/:slug/ to #{ContentDetailPaths::PROJECT_SHELL}")
  require_relative "../../_plugins/content_keys"
  check!(ContentKeys.generated_redirects_precede_catchalls?(text),
         "_redirects must place content-key 301s above /articles/:slug, /posts/:slug, and /blog/:slug 200 rewrites")

  if text.match?(%r{/social/(posts|articles)/|/social/(posts|articles)/detail})
    fail!("_redirects still targets /social/ detail shells (regression): use #{ContentDetailPaths::POST_SHELL} and #{ContentDetailPaths::ARTICLE_SHELL}")
  end
end

def prepare_synthetic_post!
  posts_dir = CONTENT_ROOT.join("collections/posts")
  synthetic = posts_dir.join("#{SYNTHETIC_SLUG}.md")
  return if synthetic.file?

  File.write(
    synthetic,
    <<~MARKDOWN
      ---
      layout: post
      title: CI detail URL gate
      date: 2099-01-01
      tags:
        - devaneio
      language: ptbr
      key: ci-detail-url-gate
      description: Synthetic fixture for detail URL regression tests.
      published: true
      ---

      #{SYNTHETIC_MARKER}
    MARKDOWN
  )
  @synthetic_created = true
end

def cleanup_synthetic_post!
  return unless @synthetic_created

  path = CONTENT_ROOT.join("collections/posts/#{SYNTHETIC_SLUG}.md")
  FileUtils.rm_f(path)

  # Re-export so a local _content_json left from this gate never retains the
  # synthetic slug (the content publish workflow no longer runs this gate).
  export_content!
end

def export_content!
  run!(%w[bundle exec ruby scripts/content/export-content-json.rb content _content_json],
       env: { "CONTENT_API_BASE_URL" => "" })
  check!(EXPORT_ROOT.join("manifest.json").file?, "Export did not write manifest.json")
end

def load_manifest
  JSON.parse(EXPORT_ROOT.join("manifest.json").read)
end

def verify_export_contract!(manifest)
  %w[posts articles].each do |collection|
    files = manifest.dig("files", collection)
    check!(files.is_a?(Array) && !files.empty?, "manifest.files.#{collection} is empty")

    files.each do |relative_path|
      json_path = EXPORT_ROOT.join(relative_path)
      check!(json_path.file?, "Missing exported JSON: #{relative_path}")

      payload = JSON.parse(json_path.read)
      slug = payload["slug"].to_s
      check!(!slug.empty?, "JSON missing slug: #{relative_path}")
      check!(payload["body_markdown"].to_s.strip != "", "JSON missing body_markdown: #{relative_path}")
    end
  end

  synth = EXPORT_ROOT.join("collections/posts/#{SYNTHETIC_SLUG}.json")
  check!(synth.file?, "Synthetic post was not exported to storage layout")
  check!(JSON.parse(synth.read)["body_markdown"].include?(SYNTHETIC_MARKER),
         "Synthetic post body missing marker text")
end

def build_shell!
  run!(%w[bundle exec jekyll build --baseurl "" --config _config.yml,_config_dev.yml],
       env: { "CONTENT_API_BASE_URL" => "" })
end

def verify_shell_structure!
  check!(SITE_ROOT.join("pages/blog/index.html").file?,
         "Missing blog listing shell at /pages/blog/")
  check!(SITE_ROOT.join("pages/articles/index.html").file?,
         "Missing articles listing shell at /pages/articles/")
  check!(SITE_ROOT.join(ContentDetailPaths::POST_SHELL.delete_prefix("/"), "index.html").file?,
         "Missing rewrite target #{ContentDetailPaths::POST_SHELL}")
  check!(SITE_ROOT.join(ContentDetailPaths::ARTICLE_SHELL.delete_prefix("/"), "index.html").file?,
         "Missing rewrite target #{ContentDetailPaths::ARTICLE_SHELL}")
  check!(SITE_ROOT.join(ContentDetailPaths::PRODUCT_SHELL.delete_prefix("/"), "index.html").file?,
         "Missing rewrite target #{ContentDetailPaths::PRODUCT_SHELL}")
  check!(SITE_ROOT.join(ContentDetailPaths::PROJECT_SHELL.delete_prefix("/"), "index.html").file?,
         "Missing rewrite target #{ContentDetailPaths::PROJECT_SHELL}")
  check!(!SITE_ROOT.join("products").directory?,
         "Static /products/ pages must not be generated; detail URLs use runtime fetch")
  check!(!SITE_ROOT.join("projects").directory?,
         "Static /projects/ pages must not be generated; detail URLs use runtime fetch")
  check!(!SITE_ROOT.join("social").directory?,
         "Obsolete /social/ shells still generated; detail URLs must reuse listing layouts")
  check!(SITE_ROOT.join("_redirects").file?, "_redirects was not copied into _site")
end

def slug_from_manifest_path(relative_path)
  File.basename(relative_path, ".json")
end

def detail_path(type, slug)
  case type
  when "post" then ContentDetailPaths.post_detail_path(slug)
  when "article" then ContentDetailPaths.article_detail_path(slug)
  when "product" then ContentDetailPaths.product_detail_path(slug)
  when "project" then ContentDetailPaths.project_detail_path(slug)
  else
    fail!("Unknown detail type: #{type}")
  end
end

def json_path(type, slug)
  collection = case type
               when "post" then "posts"
               when "article" then "articles"
               when "product" then "products"
               when "project" then "projects"
               else fail!("Unknown detail type: #{type}")
               end
  "/collections/#{collection}/#{slug}.json"
end

def http_get(port, path)
  uri = URI("http://127.0.0.1:#{port}#{path}")
  Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 10) do |http|
    http.get(uri.request_uri)
  end
end

def verify_runtime_detail!(port, type, slug)
  url = detail_path(type, slug)
  rewrite_target = ContentDetailPaths.rewrite_path(url)
  check!(rewrite_target, "No local rewrite registered for #{url}")

  shell_path = SITE_ROOT.join(rewrite_target.delete_prefix("/").chomp("/"), "index.html")
  check!(shell_path.file?, "Rewrite target missing on disk: #{rewrite_target}")

  response = http_get(port, url)
  check!(response.code.to_i == 200,
         "Detail URL #{url} returned HTTP #{response.code} (expected 200). Published content would 404 in production.")

  body = response.body.to_s
  DETAIL_RUNTIME_MARKERS.each do |marker|
    check!(body.include?(marker),
           "Detail URL #{url} is missing runtime marker #{marker.inspect}; shell cannot load storage JSON")
  end

  json_url = json_path(type, slug)
  json_response = http_get(port, json_url)
  check!(json_response.code.to_i == 200,
         "Storage JSON #{json_url} returned HTTP #{json_response.code} for slug #{slug}")

  payload = JSON.parse(json_response.body)
  check!(payload["slug"] == slug, "JSON slug mismatch for #{json_url}")
  check!(payload["body_markdown"].to_s.strip != "", "JSON body empty for #{json_url}")
end

def start_server!(port)
  log = Tempfile.new("jekyll-serve-log")
  log.close

  wrapper_pid = spawn(
    { "CONTENT_API_BASE_URL" => "" },
    "bundle", "exec", "jekyll", "serve",
    "--host", "127.0.0.1",
    "--port", port.to_s,
    "--config", "_config.yml,_config_dev.yml",
    "--skip-initial-build",
    "--no-watch",
    "--detach",
    [:out, :err] => log.path,
    chdir: REPO_ROOT.to_s
  )
  _pid, status = Process.wait2(wrapper_pid)
  output = File.read(log.path)
  fail!("jekyll serve --detach failed:\n#{output}") unless status.success?

  if output =~ /pid '(\d+)'/
    @server_pid = Regexp.last_match(1).to_i
  else
    fail!("Could not detect jekyll serve pid from output: #{output}")
  end

  Timeout.timeout(30) do
    loop do
      response = http_get(port, ContentDetailPaths::POST_SHELL)
      break if response.code.to_i == 200

      sleep 0.25
    end
  end
rescue Timeout::Error
  fail!("Timed out waiting for jekyll serve on port #{port}")
ensure
  FileUtils.rm_f(log.path)
end

def stop_server!
  return unless @server_pid

  Process.kill("TERM", @server_pid)
rescue Errno::ESRCH
  nil
ensure
  @server_pid = nil
end

def verify_all_detail_urls!(manifest, port)
  failures = []

  {
    "post" => manifest.dig("files", "posts") || [],
    "article" => manifest.dig("files", "articles") || [],
    "product" => manifest.dig("files", "products") || [],
    "project" => manifest.dig("files", "projects") || []
  }.each do |type, files|
    files.each do |relative_path|
      slug = slug_from_manifest_path(relative_path)
      begin
        verify_runtime_detail!(port, type, slug)
        puts "  OK #{detail_path(type, slug)}"
      rescue StandardError => e
        failures << "#{detail_path(type, slug)}: #{e.message}"
      end
    end
  end

  return if failures.empty?

  fail!(<<~MSG.strip)
    Detail URL gate failed for #{failures.length} published item(s):
      - #{failures.join("\n  - ")}
  MSG
end

puts "Testing content detail URLs (storage export + shell poster)..."

@synthetic_created = false
port = free_port
@server_pid = nil
manifest = nil

begin
  validate_redirects!
  prepare_synthetic_post!
  export_content!
  manifest = load_manifest
  verify_export_contract!(manifest)
  build_shell!
  verify_shell_structure!
  start_server!(port)
  verify_all_detail_urls!(manifest, port)
ensure
  stop_server!
  cleanup_synthetic_post!
end

post_count = manifest&.dig("counts", "posts") || 0
article_count = manifest&.dig("counts", "articles") || 0
product_count = manifest&.dig("counts", "products") || 0
project_count = manifest&.dig("counts", "projects") || 0
puts "All content detail URL tests passed (#{post_count} posts, #{article_count} articles, #{product_count} products, #{project_count} projects, synthetic gate included)."

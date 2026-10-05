# frozen_string_literal: true

# Refs: PLT-AC-1
require "pathname"
require "find"

ROOT = Pathname.new(__dir__).join("../..").expand_path

# Public repo home (ADR-001) may appear as a URL or Bundler github: source.
REPO_URL_OK = %r{(?:github\.com/)?alexandrelheinen/pandorga}

PATTERNS = [
  [/pub-[0-9a-f]{32}\.r2\.dev/i, "r2 bucket URL"],
  [/pk_live_[A-Za-z0-9_-]{16,}/, "live publishable key"],
  [/sk_live_[A-Za-z0-9_-]{16,}/, "live secret key"],
  [/github_pat_[A-Za-z0-9_]+/, "github pat"],
  [/Alexandre L\. Heinen/, "owner short name"],
  [/Alexandre Loeblein Heinen/, "owner full name"],
  [/alexandrelheinen\.pages\.dev/i, "pages domain"],
  [/dev\.alexandrelheinen\.studio/i, "android applicationId"]
].freeze

SKIP_DIRS = %w[
  .git
  tmp
  _site
  _content_json
  vendor
  .bundle
  node_modules
  .guidelines
  .agents
].freeze

# Migration spec documents the extraction source; .gitmodules points at the
# owner's private guidelines repo (not shipped as platform code).
ALLOW_REL = %w[
  docs/spec.md
  docs/decisions.md
  .gitmodules
].freeze

failures = []
Find.find(ROOT) do |path|
  path = Pathname.new(path)
  if path.directory?
    Find.prune if SKIP_DIRS.include?(path.basename.to_s)
    next
  end
  next unless path.file?
  next if path.basename.to_s == "test-no-personal-data.rb"
  next if path.extname.match?(/\.(png|jpe?g|gif|webp|ico|woff2?|ttf|eot|pdf|zip|gz|wasm)$/i)

  rel = path.relative_path_from(ROOT).to_s
  next if ALLOW_REL.include?(rel)

  raw = begin
    path.read(mode: "rb")
  rescue StandardError
    next
  end
  next if raw.include?("\x00")

  text = raw.force_encoding("UTF-8")
  next unless text.valid_encoding?

  # Strip allowed repo URLs before scanning for the owner slug.
  scrubbed = text.encode("UTF-8", invalid: :replace, undef: :replace).gsub(REPO_URL_OK, "")
  if scrubbed.match?(/alexandrelheinen/i)
    failures << "#{rel}: owner slug outside allowed repo URL"
  end

  PATTERNS.each do |re, label|
    next unless text.match?(re)

    failures << "#{rel}: #{label}"
  end
end

if failures.any?
  warn "FAIL test-no-personal-data:\n#{failures.uniq.join("\n")}"
  exit 1
end

puts "PASS test-no-personal-data"

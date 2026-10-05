# frozen_string_literal: true

# Refs: PLT-AC-1
require "pathname"
require "find"

ROOT = Pathname.new(__dir__).join("../..").expand_path

# The public repo URL may contain the GitHub owner; block everything else.
REPO_URL_OK = %r{github\.com/alexandrelheinen/pandorga}

PATTERNS = [
  [/pub-[0-9a-f]{32}\.r2\.dev/i, "r2 bucket URL"],
  [/pk_live_/, "live publishable key"],
  [/sk_live_/, "live secret key"],
  [/github_pat_/, "github pat"],
  [/Alexandre L\. Heinen/, "owner short name"],
  [/Alexandre Loeblein Heinen/, "owner full name"],
  [/alexandrelheinen\.pages\.dev/i, "pages domain"],
  [/dev\.alexandrelheinen\.studio/i, "android applicationId"]
].freeze

SKIP_DIRS = %w[
  .git
  tmp
  _site
  vendor
  .bundle
  node_modules
  .guidelines
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

  rel = path.relative_path_from(ROOT).to_s
  next if ALLOW_REL.include?(rel)

  text = begin
    path.read(encoding: "UTF-8")
  rescue Encoding::InvalidByteSequenceError
    next
  end

  # Strip allowed repo URLs before scanning for the owner slug.
  scrubbed = text.gsub(REPO_URL_OK, "")
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

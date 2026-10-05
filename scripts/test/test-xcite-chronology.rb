#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: article/post xcite targets must not be editorially newer than the source.
# Projects and products may be cited from any dated piece. Same-day companions
# (EN/PT pairs) may cite each other.

require "date"
require "pathname"
require "yaml"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
XCITE_RE = /\{%-?\s*include\s+xcite\.html\s+([^%]+?)-?%\}/i
KEY_ATTR_RE = /key\s*=\s*["']([^"']+)["']/i
DATED_KINDS = %w[articles posts].freeze
FREE_KINDS = %w[projects products].freeze

def check!(condition, message)
  raise message unless condition
end

def load_front_matter(path)
  text = path.read
  return [{}, ""] unless text.start_with?("---")

  parts = text.split("---", 3)
  return [{}, text] if parts.length < 3

  [YAML.safe_load(parts[1], permitted_classes: [Date, Time]) || {}, parts[2]]
end

def editorial_date(path, front_matter)
  raw = front_matter["date"]
  case raw
  when Date then return raw.iso8601
  when Time then return raw.to_date.iso8601
  when String
    day = raw.strip[0, 10]
    return day if day.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  end

  stem = path.basename.to_s
  return Regexp.last_match(1) if stem =~ /\A(\d{4}-\d{2}-\d{2})-/

  nil
end

def infer_key(path, front_matter, kind)
  key = front_matter["key"].to_s.strip
  return key unless key.empty?

  stem = path.basename(".md").to_s
  return stem.sub(/\A\d{4}-\d{2}-\d{2}-/, "") if DATED_KINDS.include?(kind)

  stem
end

puts "Testing xcite chronology (newer texts cite older texts; projects/products free)..."

entries = {}
(DATED_KINDS + FREE_KINDS).each do |kind|
  dir = REPO_ROOT.join("content/collections", kind)
  next unless dir.directory?

  dir.glob("*.md").each do |path|
    front_matter, body = load_front_matter(path)
    key = infer_key(path, front_matter, kind)
    check!(!key.empty?, "missing key for #{path.relative_path_from(REPO_ROOT)}")

    entries[key] = {
      "kind" => kind,
      "path" => path.relative_path_from(REPO_ROOT).to_s,
      "date" => editorial_date(path, front_matter),
      "body" => body
    }
  end
end

violations = []
DATED_KINDS.each do |kind|
  entries.each_value do |source|
    next unless source["kind"] == kind

    source["body"].scan(XCITE_RE).flatten.each do |attrs|
      match = KEY_ATTR_RE.match(attrs)
      next unless match

      target_key = match[1]
      target = entries[target_key]
      check!(!target.nil?, "unknown xcite key #{target_key.inspect} in #{source['path']}")
      next if FREE_KINDS.include?(target["kind"])
      next unless DATED_KINDS.include?(target["kind"])

      src_date = source["date"]
      tgt_date = target["date"]
      check!(!src_date.to_s.empty?, "missing editorial date for #{source['path']}")
      check!(!tgt_date.to_s.empty?, "missing editorial date for #{target['path']}")
      next if src_date >= tgt_date

      violations << "#{source['path']} (#{src_date}) cites newer #{target['path']} (#{tgt_date}) via key=#{target_key}"
    end
  end
end

check!(violations.empty?, "xcite chronology violations:\n  #{violations.join("\n  ")}")
puts "All xcite chronology checks passed (#{entries.size} keyed entries)."

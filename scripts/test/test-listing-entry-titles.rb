#!/usr/bin/env ruby
# frozen_string_literal: true

# PLT-AC-55: listing entry titles on the Articles, Rascunhos, Sources and
# Bibliography pages share one size, the Rascunhos step, at every width.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
CSS_ROOT = ROOT.join("assets/css")
TITLE_CLASSES = %w[.ledger-row-title .source-card-title .bib-card-title].freeze

def fail!(message)
  warn "FAIL: #{message}"
  exit 1
end

def strip_comments(source)
  source.gsub(%r{/\*.*?\*/}m, "")
end

# Yields [selectors, declarations, offset] for every rule, descending into
# at-rule blocks such as media queries.
def each_rule(source, &block)
  depth_start = 0
  i = 0
  while (open = source.index("{", i))
    prelude = source[i...open].strip
    depth = 1
    j = open + 1
    while depth.positive? && j < source.length
      depth += 1 if source[j] == "{"
      depth -= 1 if source[j] == "}"
      j += 1
    end
    body = source[(open + 1)...(j - 1)]
    if prelude.start_with?("@")
      each_rule(body, &block) if body.include?("{")
    else
      selectors = prelude.split(",").map { |s| s.strip.gsub(/\s+/, " ") }
      yield selectors, body, open + depth_start
    end
    i = j
  end
end

def last_compound(selector)
  selector.split(/\s*[ >+~]\s*/).last.to_s
end

def declares?(body, property)
  body.match?(/(?:^|;|\s)#{Regexp.escape(property)}\s*:/)
end

puts "Testing listing entry titles (PLT-AC-55)..."

base = strip_comments(CSS_ROOT.join("base.css").read)
shared = []
each_rule(base) do |selectors, body, offset|
  shared << [body, offset] if selectors.sort == TITLE_CLASSES.sort
end
fail!("base.css needs exactly one rule for #{TITLE_CLASSES.join(', ')}") unless shared.size == 1
body, shared_offset = shared.first
fail!("shared rule must set font-size: var(--type-card-lg)") unless body.match?(/font-size:\s*var\(--type-card-lg\)\s*;/)
fail!("shared rule must set line-height: 1.25") unless body.match?(/line-height:\s*1\.25\s*;/)

small_step = base.index("var(--type-card-sm)", base.index("--type-card-sm:") + 1)
fail!("small-screen .card-title step not found in base.css") unless small_step
fail!("shared rule must follow the small-screen .card-title step") unless shared_offset > small_step
puts "  shared rule: OK"

offenders = []
Dir.glob(CSS_ROOT.join("**", "*.css")).sort.each do |path|
  source = strip_comments(File.read(path))
  each_rule(source) do |selectors, rule_body, _offset|
    next if selectors.sort == TITLE_CLASSES.sort && path == CSS_ROOT.join("base.css").to_s

    targeted = selectors.select do |sel|
      compound = last_compound(sel)
      TITLE_CLASSES.any? { |cls| compound.include?(cls) && !compound.match?(/#{Regexp.escape(cls)}[-\w]/) }
    end
    next if targeted.empty?

    %w[font-size line-height].each do |prop|
      next unless declares?(rule_body, prop)

      offenders << "#{Pathname.new(path).relative_path_from(ROOT)}: #{targeted.join(', ')} sets #{prop}"
    end
  end
end
fail!("entry title overrides:\n  #{offenders.join("\n  ")}") unless offenders.empty?
puts "  no overrides: OK"

markup = {
  "_includes/content-runtime/43-blocks.html" => "ledger-row-title",
  "_layouts/resources.html" => "source-card-title",
  "_layouts/bibliography.html" => "bib-card-title"
}
markup.each do |file, cls|
  fail!("#{file} no longer emits #{cls}") unless ROOT.join(file).read.include?(cls)
end
%w[_layouts/articles.html _layouts/blog.html].each do |file|
  fail!("#{file} no longer renders rows with renderLedgerRow") unless ROOT.join(file).read.include?("renderLedgerRow(")
end
puts "  markup: OK"

puts "All listing entry title checks passed."

#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
require REPO_ROOT.join("_plugins/lib/text_excerpt").to_s

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

puts "Testing TextExcerpt listing previews..."

heading_body = <<~MD
  ## Contexto

  Os dados públicos do INSEE permitem medir os casamentos celebrados na França.
MD

excerpt = TextExcerpt.from_markdown(heading_body)
check!(excerpt.start_with?("Contexto: Os dados públicos"),
       "headings should become 'Title: ' prefixes (got #{excerpt.inspect})")

long = "palavra " * 80
truncated = TextExcerpt.from_markdown(long)
check!(truncated.end_with?("..."), "long bodies must truncate with an ellipsis")
check!(truncated.length <= 220, "truncated excerpt must stay within 220 characters")

liquid = "{% include plotly.html src=\"/media/plots/x.html\" %}\n\nDepois do gráfico vem o texto."
check!(TextExcerpt.from_markdown(liquid) == "Depois do gráfico vem o texto.",
       "liquid includes must not leak into the excerpt")

fields = TextExcerpt.listing_fields({ "description" => "  Deck editorial.  " }, heading_body)
check!(fields["description"] == "Deck editorial.",
       "listing_fields must keep the trimmed editorial description")
check!(fields["excerpt"].start_with?("Contexto:"),
       "listing_fields must still generate a body excerpt")

empty_desc = TextExcerpt.listing_fields({ "description" => "" }, heading_body)
check!(empty_desc["description"].empty?,
       "empty editorial description stays empty in the index")
check!(!empty_desc["excerpt"].empty?,
       "empty editorial description still gets a generated excerpt")

puts "All TextExcerpt checks passed."

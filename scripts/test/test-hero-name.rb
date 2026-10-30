#!/usr/bin/env ruby
# frozen_string_literal: true

# Hero name fields and headline size (docs/features/hero-name.md).
#
# PLT-AC-13 subtitle uses the body size
# PLT-AC-14 first_name / last_name, with the 1.4.9 split as fallback
# PLT-AC-15 phone name is +3pt and wraps only between the two names

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
HOME = ROOT.join("_layouts/home.html")
SHELL = ROOT.join("_layouts/shell.html")
CSS = ROOT.join("assets/css/ledger/home.css")
SCHEMA = ROOT.join("lib/pandorga/registry/schema.yml")

def check!(condition, message)
  raise "Assertion failed: #{message}" unless condition
end

puts "Testing hero name..."

# ── PLT-AC-13 ───────────────────────────────────────────────────────────────

css = CSS.read
tagline = css[/\.home-hero-tagline \{.*?\n\}/m]
check!(tagline, "missing .home-hero-tagline rule")
check!(tagline.include?("font-size: var(--type-body);"),
       "subtitle must use the body size, got:\n#{tagline}")
check!(!tagline.include?("type-label-lg"),
       "subtitle must not keep the label size")
check!(!css.include?("calc(var(--type-label-lg) + 2pt)"),
       "desktop subtitle must not add 2pt")

summary = css[/\.home-hero-summary \{.*?\n\}/m]
check!(summary, "missing .home-hero-summary rule")
check!(!summary.include?("font-size:"),
       "summary inherits the page body size and must not set its own")

# ── PLT-AC-14 ───────────────────────────────────────────────────────────────

schema = SCHEMA.read
check!(schema.include?("first_name:"), "schema missing first_name")
check!(schema.include?("last_name:"), "schema missing last_name")
check!(schema.include?("name:") && schema.include?("required: true"),
       "identity.name stays required")

home = HOME.read
shell = SHELL.read
check!(home.include?("pandorga_hero_name"),
       "home hero must resolve the name through pandorga_hero_name")
check!(home.include?("home-hero-given") && home.include?("home-hero-family"),
       "hero keeps a given span and a family span")
check!(shell.include?("pandorga_hero_name"),
       "top bar must resolve the wordmark through pandorga_hero_name")
check!(shell.include?(".wordmark"),
       "top bar prints the wordmark from the resolver")
check!(!shell.include?('site.author | default: site.title | split: " " | first'),
       "top bar must not split site.author on its own")

require "liquid"
require_relative "../../lib/pandorga/jekyll/plugins/identity_name"

template = Liquid::Template.parse(<<~LIQUID)
  {% assign hero = identity | pandorga_hero_name: author, title %}
  {{ hero.given }}|{{ hero.family }}|{{ hero.wordmark }}
LIQUID
rendered = template.render(
  "identity" => { "first_name" => "Ada", "last_name" => "Rivera Santos" },
  "author" => "Other Person",
  "title" => "Site Title"
)
check!(rendered.strip == "Ada|Rivera Santos|Ada",
       "Liquid filter must keep a multi-word last name, got #{rendered.inspect}")

both = Pandorga::IdentityName.resolve(
  { "name" => "Ada Rivera Santos", "first_name" => "Ada", "last_name" => "Rivera Santos" },
  author: "Other Person",
  title: "Site Title"
)
check!(both["given"] == "Ada", "given name, got #{both.inspect}")
check!(both["family"] == "Rivera Santos", "multi-word family name must stay whole, got #{both.inspect}")
check!(both["wordmark"] == "Ada", "top bar shows the first name, got #{both.inspect}")

spaced = Pandorga::IdentityName.resolve(
  { "first_name" => " Mary Ann ", "last_name" => " Rivera Santos " }
)
check!(spaced["given"] == "Mary Ann" && spaced["wordmark"] == "Mary Ann",
       "first_name is kept whole, got #{spaced.inspect}")
check!(spaced["family"] == "Rivera Santos",
       "last_name is trimmed but not split, got #{spaced.inspect}")

legacy = Pandorga::IdentityName.resolve(
  { "name" => "Ada Rivera Santos" },
  author: "Other Person",
  title: "Site Title"
)
check!(legacy["given"] == "Ada", "legacy given name, got #{legacy.inspect}")
check!(legacy["family"] == "Rivera Santos", "legacy family name, got #{legacy.inspect}")
check!(legacy["wordmark"] == "Ada", "legacy wordmark prefers identity.name, got #{legacy.inspect}")

partial_family = Pandorga::IdentityName.resolve(
  { "name" => "Someone Else", "last_name" => "Rivera Santos" }
)
check!(partial_family["given"] == "Someone", "missing first_name uses the first word of name")
check!(partial_family["family"] == "Rivera Santos", "explicit last_name replaces the remainder")
check!(partial_family["wordmark"] == "Someone", "missing first_name wordmark is the first word of name")

partial_given = Pandorga::IdentityName.resolve({ "name" => "Ada Example", "first_name" => "Ada" })
check!(partial_given["family"] == "Example", "missing last_name keeps the remainder of name")
check!(partial_given["wordmark"] == "Ada", "wordmark uses first_name")

blank_last = Pandorga::IdentityName.resolve({ "name" => "Ada Example", "last_name" => "" })
check!(blank_last["family"] == "Example", "blank last_name keeps the 1.4.9 remainder")

author_only = Pandorga::IdentityName.resolve({}, author: "Other Person", title: "Site Title")
check!(author_only["given"] == "Other" && author_only["family"] == "Person",
       "name falls back to site.author, got #{author_only.inspect}")
check!(author_only["wordmark"] == "Other", "wordmark falls back to site.author")

title_only = Pandorga::IdentityName.resolve({}, title: "Site Title")
check!(title_only["given"] == "" && title_only["family"] == "",
       "hero does not take site.title, got #{title_only.inspect}")
check!(title_only["wordmark"] == "Site", "wordmark falls back to site.title")

long_name = (["Ada"] + (1..9).map { |index| "Tok#{index}" }).join(" ")
long = Pandorga::IdentityName.resolve({ "name" => long_name })
check!(long["family"] == (1..8).map { |index| "Tok#{index}" }.join(" "),
       "legacy remainder stays eight words, got #{long["family"].inspect}")

symbols = Pandorga::IdentityName.resolve({ first_name: "Ada", last_name: "Rivera Santos" })
check!(symbols["family"] == "Rivera Santos", "symbol keys work, got #{symbols.inspect}")

# ── PLT-AC-15 / PLT-AC-98 ───────────────────────────────────────────────────

hero = css[/\.home-hero-title \{.*?(?=\.home-hero-summary)/m]
check!(hero, "missing hero title block")
check!(hero.include?("font-size: calc(var(--type-section) + 2pt);"),
       "base name size is type-section + 2pt (PLT-AC-98)")
check!(hero.include?("font-size: calc(var(--type-section-lg) + 2pt);"),
       "from 768px name is type-section-lg + 2pt (PLT-AC-98)")
check!(!hero.include?("100cqi") && !css.include?("1.85rem, 2.6vw") && !css.include?("1.9rem, 7vw"),
       "hero name must not use cqi/vw clamps (PLT-AC-98)")

phone = hero[/@media \(max-width: 767px\) \{.*?\n\}/m]
# Nested rules: match from the media opener through the last name part selectors.
check!(hero.include?("@media (max-width: 767px)") &&
         hero.include?(".home-hero-given") &&
         hero.include?(".home-hero-family") &&
         hero.include?("inline-block") &&
         hero.include?("white-space: nowrap"),
       "on a phone each name is an unbreakable unit")

desktop = hero[/@media \(min-width: 768px\)[\s\S]*?(?=\.home-hero-summary|\z)/]
check!(desktop && desktop.include?("white-space: nowrap"),
       "from 768px the name stays on one line")
check!(desktop && desktop.include?("var(--type-section-lg) + 2pt"),
       "768px media must set type-section-lg + 2pt")

puts "PASS test-hero-name"

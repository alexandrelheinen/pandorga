#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate: every filter facet a page offers must be a facet the filter reads.
#
# ListingFilter keeps one state object. A chip group writes `state[group.key]`
# on click; `filterItems` reads a fixed set of names. Nothing connects the
# two, so renaming a facet in a layout — `category` to `tag`, say — leaves the
# chips rendering, highlighting and pushing a query string while the list
# beNewsreader them never changes. That shipped on the Sources page: every click set
# a key nothing read.
#
# There is no build error and no console error to notice, so the contract is
# checked here: chip-group keys against the state ListingFilter initialises
# and the names filterItems actually consumes, plus the URL parameters a
# layout can set against the ones syncUrl clears.

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
FILTER = ROOT.join("_includes/content-runtime/42-listing-filter.html")
LAYOUT_DIR = ROOT.join("_layouts")

# A chip group is the only place a layout writes `key: '<literal>'` followed by
# a label. Matching the pair keeps unrelated object literals out.
CHIP_GROUP_KEY = /key:\s*(['"])(\w+)\1\s*,\s*(?:\/\*.*?\*\/\s*|\/\/[^\n]*\n\s*)*label:/m
PARAM_OPTION = /(?:tagParam|categoryParam):\s*(['"])([\w-]+)\1/

def fail!(message)
  warn message
  exit 1
end

def check!(condition, message)
  fail!(message) unless condition
end

puts "Testing the listing filter facet contract..."

source = FILTER.read

state_block = source[/var state = \{(.*?)\n        \};/m, 1]
check!(!state_block.nil?, "could not find the ListingFilter state object in #{FILTER}")
state_keys = state_block.scan(/^\s*(\w+):/).flatten.uniq
check!(state_keys.length >= 3, "only found state keys #{state_keys.inspect}; the regex has drifted")

filter_items = source[/filterItems: function \(items, state, options\) \{(.*?)\n      \}\n    \};/m, 1]
check!(!filter_items.nil?, "could not find ListingFilter.filterItems in #{FILTER}")
read_keys = filter_items.scan(/\bstate\.(\w+)/).flatten.uniq
check!(read_keys.length >= 3, "only found read keys #{read_keys.inspect}; the regex has drifted")

sync_url = source[/function syncUrl\(\) \{(.*?)\n        \}/m, 1]
check!(!sync_url.nil?, "could not find syncUrl in #{FILTER}")
cleared_params = sync_url[/\[(.*?)\]\.forEach/m, 1].to_s.scan(/['"]([\w-]+)['"]/).flatten
check!(cleared_params.any?, "syncUrl clears no query parameters; the regex has drifted")

# Dead state is a facet waiting to happen: something can set it and nothing
# will ever act on it.
dead = state_keys - read_keys
check!(
  dead.empty?,
  "ListingFilter initialises #{dead.inspect} but filterItems never reads " \
  "#{dead.length == 1 ? 'it' : 'them'}. A chip group keyed on a dead name " \
  "filters nothing."
)

groups = 0
layouts_with_groups = []

Dir.glob(LAYOUT_DIR.join("*.html")).sort.each do |path|
  layout = Pathname.new(path)
  body = layout.read
  keys = body.scan(CHIP_GROUP_KEY).map { |_, key| key }
  next if keys.empty?

  layouts_with_groups << layout.basename.to_s
  groups += keys.length

  keys.uniq.each do |key|
    check!(
      state_keys.include?(key),
      "#{layout.basename}: chip group keyed on '#{key}', which ListingFilter " \
      "never initialises (it knows #{state_keys.sort.inspect}). Clicking a " \
      "chip would set a key nothing reads."
    )
    check!(
      read_keys.include?(key),
      "#{layout.basename}: chip group keyed on '#{key}', which filterItems " \
      "never reads (it consumes #{read_keys.sort.inspect}). The chips would " \
      "highlight and the list would not move."
    )
  end

  check!(
    body.include?("ListingFilter.filterItems"),
    "#{layout.basename} builds chip groups but never calls " \
    "ListingFilter.filterItems, so no click can reach the list"
  )

  body.scan(PARAM_OPTION).each do |_, param|
    check!(
      cleared_params.include?(param),
      "#{layout.basename} writes ?#{param}= but syncUrl never clears it " \
      "(clears #{cleared_params.inspect}), so switching facets leaves a stale filter in the URL"
    )
  end
end

check!(
  layouts_with_groups.length >= 3,
  "only #{layouts_with_groups.inspect} declare chip groups; the redesign put a " \
  "filter deck on every listing page, so the scan has probably stopped matching"
)
check!(groups >= 5, "only found #{groups} chip groups; the scan has probably stopped matching")

puts "  state: #{state_keys.sort.join(', ')}"
puts "  read by filterItems: #{read_keys.sort.join(', ')}"
puts "  #{groups} chip group(s) across #{layouts_with_groups.join(', ')}"
puts "All listing filter facet checks passed."

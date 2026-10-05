#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
SCRIPT = Pathname.new(__dir__).join("test-math-row-breaks.mjs")

puts "Testing math row-break normalization..."
stdout, stderr, status = Open3.capture3("node", SCRIPT.to_s, chdir: ROOT.join("scripts").to_s)
unless status.success?
  warn stderr
  warn stdout
  raise "math row-break tests failed"
end
puts stdout
puts "All math row-break tests passed."

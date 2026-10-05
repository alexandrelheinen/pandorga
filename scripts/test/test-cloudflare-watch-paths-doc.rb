#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
DOC = ROOT.join("docs/ops/cloudflare.md")

def check!(condition, message = "condition was false")
  raise "Assertion failed: #{message}" unless condition
end

text = DOC.read

puts "Testing Cloudflare watch paths documentation..."

check! text.include?("`*`"), "missing include pattern `*`"
check! text.include?("`content/*`"), "missing exclude pattern content/*"
check! text.include?("`docs/*`"), "missing exclude pattern docs/*"
check! text.include?("Settings → Build → Build watch paths"),
       "missing dashboard navigation path"
check! text.include?("SKIP_DEPENDENCY_INSTALL"),
       "missing SKIP_DEPENDENCY_INSTALL (avoids Pages pip install of study deps)"
check! text.include?("bundle install") && text.include?("jekyll build"),
       "missing lean Pages build command with explicit bundle install"
check! text.include?("pandorga install-functions"),
       "missing pandorga install-functions in Pages build command (PLT-0.2)"
check! text.include?("3.4.4"),
       "missing Pages v3 Ruby 3.4.4 pin (avoids compiling Ruby from source)"

puts "Cloudflare watch paths documentation OK."

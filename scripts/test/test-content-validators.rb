#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

require_relative "../../_plugins/lib/content_validators"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path

puts "Testing ContentValidators..."
ContentValidators.validate_all!(ROOT)
puts "All ContentValidators checks passed."

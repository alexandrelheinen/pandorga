#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

require_relative "../../_plugins/content_keys"

REPO_ROOT = Pathname.new(__dir__).join("..", "..").expand_path

ContentKeys.validate!(REPO_ROOT)
ContentKeys.sync_redirects_file!(REPO_ROOT)
puts "Content redirects synced to #{REPO_ROOT.join('_redirects')}"

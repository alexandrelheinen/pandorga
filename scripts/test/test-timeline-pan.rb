#!/usr/bin/env ruby
# frozen_string_literal: true

# CV timeline temporal pan static gate (PLT-AC-47, docs/features/timeline-pan.md).
#
# Asserts:
# - wrapper has tabindex="0", role="region", and aria-label
# - pan prev/next and Today buttons exist with aria-labels
# - script registers pointerdown, pointermove, pointerup, and keydown handlers
# - shiftKey is checked on the selection path
# - changeZoom no longer calls scrollToToday()
# - prefers-reduced-motion check is present
# - hint text "Shift+drag to select a period" is present

require "pathname"

ROOT = Pathname.new(__dir__).join("..", "..").expand_path
TIMELINE_HTML = ROOT.join("_includes/page/timeline-section.html")

def fail!(msg)
  warn "FAIL test-timeline-pan: #{msg}"
  exit 1
end

source = TIMELINE_HTML.read

# 1. Wrapper accessibility attributes
wrapper_match = source[/<div[^>]*id=["']timeline-chart-wrapper["'][^>]*>/]
fail!("missing #timeline-chart-wrapper") unless wrapper_match
fail!("wrapper missing tabindex=\"0\"") unless wrapper_match.include?('tabindex="0"')
fail!("wrapper missing role=\"region\"") unless wrapper_match.include?('role="region"')
fail!("wrapper missing aria-label") unless wrapper_match.include?('aria-label=')

# 2. Pan and Today buttons with aria-labels inside #timeline-zoom-controls
zoom_controls = source[/<div[^>]*id=["']timeline-zoom-controls["'][^>]*>.*?<\/div>/m]
fail!("missing #timeline-zoom-controls") unless zoom_controls

fail!("missing pan prev button (‹)") unless zoom_controls.include?("‹")
fail!("missing pan next button (›)") unless zoom_controls.include?("›")
fail!("missing Today button") unless zoom_controls.include?("Today")

prev_btn = zoom_controls[/<button[^>]*>[^<]*‹[^<]*<\/button>/m]
fail!("pan prev button missing aria-label") unless prev_btn && prev_btn.include?("aria-label=")

next_btn = zoom_controls[/<button[^>]*>[^<]*›[^<]*<\/button>/m]
fail!("pan next button missing aria-label") unless next_btn && next_btn.include?("aria-label=")

today_btn = zoom_controls[/<button[^>]*>[^<]*Today[^<]*<\/button>/m]
fail!("Today button missing aria-label") unless today_btn && today_btn.include?("aria-label=")

# 3. Pointer and keyboard event handlers registered in the script
script_match = source[/<script>(.*?)<\/script>/m, 1]
fail!("inline script missing") unless script_match

fail!("script missing pointerdown handler") unless script_match.include?("pointerdown")
fail!("script missing pointermove handler") unless script_match.include?("pointermove")
fail!("script missing pointerup handler") unless script_match.include?("pointerup")
fail!("script missing keydown handler") unless script_match.include?("keydown")

# 4. shiftKey checked on the selection path
fail!("script does not check shiftKey for selection") unless script_match.include?("shiftKey")

# 5. changeZoom no longer calls scrollToToday()
# Brace-matched body, so a nested block cannot hide a later call.
def function_body(script, name)
  head = script.index(/function\s+#{name}\s*\([^)]*\)\s*\{/)
  return nil unless head

  open_at = script.index("{", head)
  depth = 0
  script[open_at..].each_char.with_index do |char, offset|
    depth += 1 if char == "{"
    depth -= 1 if char == "}"
    return script[open_at + 1, offset - 1] if depth.zero?
  end
  nil
end

change_zoom_body = function_body(script_match, "changeZoom")
fail!("missing changeZoom function") unless change_zoom_body
if change_zoom_body.include?("scrollToToday")
  fail!("changeZoom must not call scrollToToday(); zoom must preserve center date")
end

# 6. prefers-reduced-motion check present
fail!("missing prefers-reduced-motion check") unless script_match.include?("prefers-reduced-motion")

# 7. Selection hint text present
fail!("missing hint text 'Shift+drag to select a period'") unless source.include?("Shift+drag to select a period")

puts "PASS test-timeline-pan (PLT-AC-47)"

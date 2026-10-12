# frozen_string_literal: true

module Pandorga
  # Splat 200 lines that serve every detail URL from one listing shell.
  # Cloudflare follows `_redirects` for the request, and the shell loads
  # the entry from the content runtime. The source file is left alone;
  # a missing line is added only to the published copy.
  module DetailRoutes
    SHELL_REWRITES = [
      ["/articles/:slug", "/pages/articles/"],
      ["/posts/:slug", "/pages/blog/"],
      ["/blog/:slug", "/pages/blog/"],
      ["/projects/:slug", "/pages/projects/"],
      ["/products/:slug", "/pages/cv/"]
    ].freeze

    module_function

    def ensure_shell_rewrites(text)
      body = text.to_s
      missing = SHELL_REWRITES.reject { |prefix, _target| rewrite_present?(body, prefix) }
      return body if missing.empty?

      addition = missing.map { |prefix, target| "#{prefix} #{target} 200" }.join("\n")
      stripped = body.rstrip
      stripped.empty? ? "#{addition}\n" : "#{stripped}\n#{addition}\n"
    end

    def rewrite_present?(text, prefix)
      text.to_s.lines.any? do |line|
        stripped = line.strip
        stripped.match?(%r{\A#{Regexp.escape(prefix)}/?\s+\S+\s+200\z})
      end
    end
  end
end

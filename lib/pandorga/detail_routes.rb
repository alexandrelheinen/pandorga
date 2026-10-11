# frozen_string_literal: true

module Pandorga
  # Detail URLs that used to be 200-rewritten onto a listing shell.
  # Cloudflare follows `_redirects` even when a static file exists, so the
  # built file must drop those splat lines or the generated page is never
  # served. The source file is left alone.
  module DetailRoutes
    SPLAT_LINE = %r{\A/(?:articles|posts|blog|projects|products)/(?::slug|\*)/?\s+\S+\s+200\s*\z}

    module_function

    def strip_splat_rewrites(text)
      text.to_s.lines.reject { |line| SPLAT_LINE.match?(line.strip) }.join
    end

    def static_index?(root, path)
      root = root.to_s
      return false if root.empty?

      clean = path.to_s.split("?").first.to_s
      relative = clean.sub(%r{\A/}, "").sub(%r{/\z}, "")
      return false if relative.empty? || relative.include?("..")

      File.file?(File.join(root, relative, "index.html")) ||
        File.file?(File.join(root, "#{relative}.html"))
    end
  end
end

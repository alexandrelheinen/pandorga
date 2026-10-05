# frozen_string_literal: true

require "date"
require "shellwords"
require "open3"

# Derives publication and last-modification dates for articles and posts.
# Shared by the content JSON export script and Jekyll build-time indexers.
#
# `date` — editorial creation date: front matter `date`, else the YYYY-MM-DD filename
#   prefix, else the first Git add (legacy files without a dated name).
# `last_updated` — latest commit where the markdown body (after the closing ---) changed;
#   front-matter-only edits do not advance it.
#
# Pitfall (see docs/content/architecture.md): history often crosses renames. git log --follow
# reaches pre-migration commits, but git show <sha>:<current-path> does not — the path did
# not exist yet. A failed show must never be treated as an empty body; resolve the path per
# commit via git_commit_entries (--name-only) before comparing bodies.
module GitChronology
  WRITING_TYPES = %w[article post].freeze
  FILENAME_DATE_RE = /\A(\d{4}-\d{2}-\d{2})-/.freeze

  module_function

  def reset_cache!
    @chronology_memo = {}
  end

  def git_repo?
    system("git rev-parse --is-inside-work-tree > /dev/null 2>&1")
  end

  def git_date(repo_relative_path, mode)
    return nil unless git_repo?

    path = repo_relative_path.to_s
    case mode
    when :creation
      raw_out, _status = Open3.capture2("git", "log", "--follow", "--diff-filter=A", "--format=%ad", "--date=short", "--", path)
      raw = raw_out.strip.split("\n").last
    when :updated
      # AM skips pure rename/copy commits (e.g. content migration) while still
      # returning the add date for files that have only been created once.
      raw_out, _status = Open3.capture2("git", "log", "--follow", "--diff-filter=AM", "-1", "--format=%ad", "--date=short", "--", path)
      raw = raw_out.strip
    else
      return nil
    end

    raw unless raw.nil? || raw.empty?
  end

  def split_front_matter(text)
    text = text.to_s.sub(/\A\xEF\xBB\xBF/, "")
    return ["", text] unless text.start_with?("---\n")

    parts = text.split(/^---\s*$\n?/, 3)
    return ["", text] unless parts.length == 3

    [parts[1], parts[2]]
  end

  def markdown_body(text)
    _front_matter, body = split_front_matter(text)
    body
  end

  # Chronology compares semantic body content, not formatting noise from CMS saves
  # (line endings, trailing spaces, or blank lines added/removed without text edits).
  def normalize_body_for_chronology(body)
    body.to_s
        .gsub(/\r\n?/, "\n")
        .each_line
        .map(&:strip)
        .reject(&:empty?)
        .join("\n")
  end

  def bodies_changed_for_chronology?(body_a, body_b)
    normalize_body_for_chronology(body_a) != normalize_body_for_chronology(body_b)
  end

  SHA_RE = /\A[0-9a-f]{40}\z/i

  # Newest-first [commit_sha, repo_relative_path_at_that_commit] pairs.
  #
  # --follow alone is insufficient for body chronology: each revision must be read at the
  # path that existed in that commit (_posts/… before the 2026-06-19 content/ migration,
  # content/collections/posts/… after). Without --name-only, git show sha:current_path
  # fails on older commits and last_updated incorrectly snaps to the rename date.
  def git_commit_entries(repo_relative_path)
    return [] unless git_repo?

    path = repo_relative_path.to_s
    out, _status = Open3.capture2("git", "log", "--follow", "--name-only", "--format=%H", "--", path)
    lines = out.each_line.map(&:strip).reject(&:empty?)
    return [] if lines.empty?

    entries = []
    index = 0
    while index < lines.length
      sha = lines[index]
      break unless sha.match?(SHA_RE)

      index += 1
      paths = []
      while index < lines.length && !lines[index].match?(SHA_RE)
        paths << lines[index]
        index += 1
      end

      path_at_commit = paths.empty? ? repo_relative_path.to_s : pick_path_at_commit(paths, repo_relative_path)
      entries << [sha, path_at_commit]
    end
    entries
  end

  def pick_path_at_commit(paths, repo_relative_path)
    basename = File.basename(repo_relative_path.to_s)
    paths.find { |candidate| candidate.end_with?(basename) } || paths.last
  end

  def commit_date(sha)
    out, _status = Open3.capture2("git", "log", "-1", "--format=%ad", "--date=short", sha)
    out.strip
  end

  def file_content_at_commit(path_at_commit, sha)
    # path_at_commit comes from git_commit_entries, not the caller's present-day path.
    path = path_at_commit.to_s
    content, status = Open3.capture2("git", "show", "#{sha}:#{path}", err: File::NULL)
    return nil unless status.success?
    return nil if content.nil? || content.empty?

    content
  end

  def git_body_updated_date(repo_relative_path)
    entries = git_commit_entries(repo_relative_path)
    return nil if entries.empty?

    # Walk newest → oldest; stop at the first pair where bodies differ.
    # Do not substitute "" when file_content_at_commit returns nil — that was the
    # migration bug (missing historical path read as an empty body edit).
    entries.each_with_index do |(sha, path_at_commit), idx|
      body = markdown_body(file_content_at_commit(path_at_commit, sha) || "")
      if idx == entries.length - 1
        return nil
      end

      older_sha, older_path = entries[idx + 1]
      older_body = markdown_body(file_content_at_commit(older_path, older_sha) || "")
      return commit_date(sha) if bodies_changed_for_chronology?(body, older_body)
    end

    nil
  end

  def filename_date(repo_relative_path)
    stem = File.basename(repo_relative_path.to_s, File.extname(repo_relative_path.to_s))
    match = stem.match(FILENAME_DATE_RE)
    normalize_date_value(match[1]) if match
  end

  def editorial_date(front_matter, repo_relative_path)
    normalize_date_value(front_matter["date"]) ||
      filename_date(repo_relative_path) ||
      git_date(repo_relative_path, :creation)
  end

  def chronology_for(repo_relative_path, type: nil, front_matter: nil)
    return {} unless type.nil? || WRITING_TYPES.include?(type)

    @chronology_memo ||= {}
    memo_key = [repo_relative_path.to_s, type, normalize_date_value(front_matter&.dig("date"))]
    return @chronology_memo[memo_key] if @chronology_memo.key?(memo_key)

    fm = front_matter || {}
    creation = editorial_date(fm, repo_relative_path)
    updated = git_body_updated_date(repo_relative_path)
    last_updated = updated || creation

    result = {}
    result["date"] = creation if creation
    result["last_updated"] = last_updated if last_updated
    @chronology_memo[memo_key] = result
    result
  end

  def normalize_date_value(value)
    case value
    when Date then value.iso8601
    when Time then value.to_date.iso8601
    when String
      stripped = value.strip
      stripped.empty? ? nil : stripped
    else
      raw = value&.to_s&.strip
      raw.nil? || raw.empty? ? nil : raw
    end
  end

  def apply!(front_matter, repo_relative_path, type)
    return front_matter unless WRITING_TYPES.include?(type)

    chronology = chronology_for(repo_relative_path, type: type, front_matter: front_matter)
    front_matter["date"] = chronology["date"] if chronology["date"]
    front_matter["last_updated"] = chronology["last_updated"] if chronology["last_updated"]
    front_matter
  end
end

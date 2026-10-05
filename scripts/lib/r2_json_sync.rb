# frozen_string_literal: true

# Plan an incremental JSON prefix replace against S3-compatible list-objects.
# A single-part ETag is an MD5 hex digest; matching local MD5 means skip PUT.
# Multipart ETags contain "-" and must be re-uploaded. Missing/blank ETags too.
# Remote keys absent locally are deleted so withdrawn/renamed objects cannot stay.
module R2JsonSync
  FORCE_UPLOAD_BASENAMES = %w[writing_index.json].freeze

  module_function

  def normalize_etag(etag)
    etag.to_s.gsub('"', "").strip
  end

  def multipart_etag?(etag)
    normalize_etag(etag).include?("-")
  end

  def skip_upload?(remote_etag, local_md5, key: nil)
    return false if force_upload_key?(key)

    etag = normalize_etag(remote_etag)
    return false if etag.empty? || multipart_etag?(etag)

    etag.casecmp?(local_md5.to_s)
  end

  def force_upload_key?(key)
    FORCE_UPLOAD_BASENAMES.include?(File.basename(key.to_s))
  end

  def contents_to_etags(contents)
    etags = {}
    Array(contents).each do |item|
      key = item.is_a?(Hash) ? item["Key"].to_s : ""
      next if key.empty? || key.end_with?("/")

      etags[key] = normalize_etag(item["ETag"])
    end
    etags
  end

  # local_files: array of { "key" =>, "md5" => }
  # remote_etags: { key => etag }
  def plan(local_files, remote_etags)
    remote = remote_etags.transform_keys(&:to_s)
    upload = []
    skip = []
    local_keys = []

    Array(local_files).each do |file|
      key = file["key"].to_s
      next if key.empty?

      local_keys << key
      md5 = file["md5"].to_s
      if skip_upload?(remote[key], md5, key: key)
        skip << key
      else
        upload << key
      end
    end

    {
      "upload" => upload,
      "skip" => skip,
      "delete" => (remote.keys - local_keys).sort
    }
  end

  def summary_line(prefix, plan)
    "R2 replace sync #{prefix}/: uploaded=#{Array(plan['upload']).length} " \
      "skipped=#{Array(plan['skip']).length} deleted=#{Array(plan['delete']).length}"
  end
end

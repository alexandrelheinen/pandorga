# frozen_string_literal: true

# Resolve S3-compatible object-store credentials from S3_* or legacy R2_* env.
module Pandorga
  module ObjectStoreEnv
    PAIRS = {
      "endpoint" => %w[S3_ENDPOINT R2_ENDPOINT],
      "bucket" => %w[S3_BUCKET R2_BUCKET],
      "access_key_id" => %w[S3_ACCESS_KEY_ID R2_ACCESS_KEY_ID AWS_ACCESS_KEY_ID],
      "secret_access_key" => %w[S3_SECRET_ACCESS_KEY R2_SECRET_ACCESS_KEY AWS_SECRET_ACCESS_KEY],
      "region" => %w[S3_REGION R2_REGION AWS_DEFAULT_REGION],
      "account_id" => %w[S3_ACCOUNT_ID R2_ACCOUNT_ID]
    }.freeze

    module_function

    def fetch(key, default = nil)
      names = PAIRS[key.to_s] || [key.to_s]
      names.each do |name|
        value = ENV[name].to_s
        return value unless value.empty?
      end
      default
    end

    def require!(*keys)
      missing = keys.select { |key| fetch(key).to_s.empty? }
      return if missing.empty?

      hints = missing.map do |key|
        names = PAIRS[key.to_s] || [key.to_s]
        "#{key} (#{names.join(' / ')})"
      end
      raise ArgumentError, "missing object-store env: #{hints.join(', ')}"
    end

    def apply_aws_env!
      ENV["AWS_ACCESS_KEY_ID"] = fetch("access_key_id") if ENV["AWS_ACCESS_KEY_ID"].to_s.empty?
      ENV["AWS_SECRET_ACCESS_KEY"] = fetch("secret_access_key") if ENV["AWS_SECRET_ACCESS_KEY"].to_s.empty?
      region = fetch("region", "auto")
      ENV["AWS_DEFAULT_REGION"] = region if ENV["AWS_DEFAULT_REGION"].to_s.empty?

      # Keep legacy R2_* populated so existing sync scripts keep working.
      ENV["R2_ENDPOINT"] = fetch("endpoint") if ENV["R2_ENDPOINT"].to_s.empty?
      ENV["R2_BUCKET"] = fetch("bucket") if ENV["R2_BUCKET"].to_s.empty?
      ENV["R2_ACCESS_KEY_ID"] = fetch("access_key_id") if ENV["R2_ACCESS_KEY_ID"].to_s.empty?
      ENV["R2_SECRET_ACCESS_KEY"] = fetch("secret_access_key") if ENV["R2_SECRET_ACCESS_KEY"].to_s.empty?
      ENV["R2_REGION"] = region if ENV["R2_REGION"].to_s.empty?
    end
  end
end

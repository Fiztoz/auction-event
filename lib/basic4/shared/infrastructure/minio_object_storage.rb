require "json"
require "aws-sdk-s3"
require_relative "../shared"
require_relative "../ports/object_storage"

# MinIO (S3-compatible) adapter for Basic4::Ports::ObjectStorage. Module-function
# style like the other adapters; the S3 client and config are read from the
# environment and memoized.
module Basic4::Infrastructure::MinioObjectStorage
  module_function

  def put(key:, io:, content_type:)
    client.put_object(bucket: bucket, key: key, body: io, content_type: content_type)
    "#{public_url}/#{bucket}/#{key}"
  rescue Aws::S3::Errors::NoSuchBucket
    # The bucket may not exist yet if the app booted before MinIO was ready;
    # create it on demand and retry once.
    ensure_bucket!
    client.put_object(bucket: bucket, key: key, body: io, content_type: content_type)
    "#{public_url}/#{bucket}/#{key}"
  end

  # Idempotently create the bucket and grant anonymous read on its objects, so
  # the URLs returned by #put resolve directly in <img> tags.
  def ensure_bucket!
    client.head_bucket(bucket: bucket)
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
    client.create_bucket(bucket: bucket)
    client.put_bucket_policy(bucket: bucket, policy: public_read_policy)
    nil
  end

  def client
    @client ||= Aws::S3::Client.new(
      endpoint:         ENV.fetch("MINIO_ENDPOINT", "http://localhost:9000"),
      access_key_id:    ENV.fetch("MINIO_ACCESS_KEY", "minioadmin"),
      secret_access_key: ENV.fetch("MINIO_SECRET_KEY", "minioadmin"),
      region:           ENV.fetch("MINIO_REGION", "us-east-1"),
      force_path_style: true
    )
  end

  def bucket
    ENV.fetch("MINIO_BUCKET", "basic4-products")
  end

  # Browser-facing base URL (may differ from the server-side MINIO_ENDPOINT, e.g.
  # `minio:9000` inside Docker vs `localhost:9000` from the browser).
  def public_url
    ENV.fetch("MINIO_PUBLIC_URL", ENV.fetch("MINIO_ENDPOINT", "http://localhost:9000"))
  end

  def public_read_policy
    {
      "Version" => "2012-10-17",
      "Statement" => [{
        "Effect"    => "Allow",
        "Principal" => { "AWS" => ["*"] },
        "Action"    => ["s3:GetObject"],
        "Resource"  => ["arn:aws:s3:::#{bucket}/*"]
      }]
    }.to_json
  end
end

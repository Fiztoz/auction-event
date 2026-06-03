require_relative "../shared"

# Port for blob/object storage (product images).
#
# Required module methods on adapters:
#   put(key:, io:, content_type:) -> String   (public URL of the stored object)
#   ensure_bucket!                -> nil       (idempotently create the bucket + public-read policy)
module Basic4::Ports::ObjectStorage
end

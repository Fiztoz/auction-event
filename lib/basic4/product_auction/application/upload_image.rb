require "securerandom"
require_relative "../../shared/shared"
require_relative "../../shared/result"
require_relative "../../shared/ports/object_storage"
require_relative "../../shared/container"

module Basic4::ProductAuction::Application::UploadImage
  module_function

  CONTENT_TYPES = {
    "image/jpeg" => ".jpg",
    "image/png"  => ".png",
    "image/webp" => ".webp",
    "image/gif"  => ".gif"
  }.freeze

  MAX_BYTES = 5 * 1024 * 1024

  def call(seller_id, io:, content_type:, size:, container: Basic4::Container.production)
    ext = CONTENT_TYPES[content_type.to_s]
    return Basic4::Result.failure(:image, "unsupported image type") unless ext
    return Basic4::Result.failure(:image, "image too large (max 5 MB)") if size.to_i > MAX_BYTES

    key = "products/#{seller_id}/#{SecureRandom.uuid}#{ext}"
    url = container[:object_storage].put(key: key, io: io, content_type: content_type)
    Basic4::Result.success({ url: url })
  end
end

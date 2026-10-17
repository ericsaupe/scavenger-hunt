namespace :storage do
  desc "Apply the bucket CORS rule that browser direct uploads need. ORIGINS adds comma-separated extra origins."
  task cors: :environment do
    service = ActiveStorage::Blob.service
    abort "Active Storage service is #{service.class.name}, not S3; set ACTIVE_STORAGE_SERVICE=amazon" unless service.respond_to?(:bucket)

    origins = ["https://www.scavengerhunt.party", "https://scavengerhunt.party", "http://localhost:3000"] + ENV.fetch("ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
    bucket = service.bucket.name
    service.client.client.put_bucket_cors(
      bucket: bucket,
      cors_configuration: {
        cors_rules: [{
          allowed_origins: origins,
          allowed_methods: %w[PUT GET],
          allowed_headers: ["*"],
          expose_headers: %w[ETag],
          max_age_seconds: 3600
        }]
      }
    )
    rules = service.client.client.get_bucket_cors(bucket: bucket).cors_rules
    puts "#{bucket}: #{rules.size} CORS rule(s), origins #{rules.flat_map(&:allowed_origins).join(", ")}"
  end
end

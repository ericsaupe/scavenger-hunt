# Scavenger Hunt Party!

Scavenger Hunt Party! is a simple web app to manage the experience of a photo scavenger hunt. A photo scavenger hunt is a scavenger hunt where the participants are required to take a photo or video of the item for it to count as being found. When the scavenger hunt is over all participants can see the results as well as the photos and videos taken by others.

## Development

### Installation
- `bin/setup`

### Running
- `bin/dev`

### Testing
- `bin/test`

### Errors

- `[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called`
  - Seems to be an issue with Ruby and MacOS and VIPS and ImageMagick and whatever https://github.com/rails/rails/issues/38560. The fix is to run `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` before running the server.

### Uploads

Photos and videos go straight from the browser to the storage service with Active Storage direct uploads, then the form sends the signed blob id to the app. In production the service is S3 (`config/storage.yml`), so the bucket needs a CORS rule that lets the site `PUT` objects and read the `ETag` header back. In the bucket's **Permissions → Cross-origin resource sharing** add:

```json
[
  {
    "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "AllowedMethods": ["PUT"],
    "AllowedOrigins": ["https://scavengerhunt.party"],
    "ExposeHeaders": ["ETag", "Origin"],
    "MaxAgeSeconds": 3600
  }
]
```

Add every origin the app is served from (staging, custom domains) to `AllowedOrigins`. Without the rule the browser blocks the upload and teams see the "couldn't be uploaded" banner on every attempt. Development and test use the Disk service, which needs no CORS setup.

Videos are limited to 50 MB and 30 seconds (`Submission::MAX_VIDEO_BYTES`, `Submission::MAX_VIDEO_SECONDS`); the browser checks both before uploading and the server checks the size again. Photos are compressed in the browser before upload. A photo captured before the hunt ended is still accepted for 15 minutes after the end (`Hunt::LATE_UPLOAD_GRACE`) so slow connections do not lose last-minute finds.

## Adding New Scavenger Hunt Templates

One of the features of Scavenger Hunt is ready made hunt templates. These are loaded in during app boot from `app/templates`. To create a new scavenger hunt template just make a new YAML file in `app/templates` that is structured like a `Hunt` model with associated `Category`s and `Item`s.

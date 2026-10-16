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

Videos are limited to 50 MB and 30 seconds (`Submission::MAX_VIDEO_BYTES`, `Submission::MAX_VIDEO_SECONDS`); the browser checks both before uploading, the server checks the size when the upload lands, and the worker probes the duration with ffprobe before converting and refuses clips that are too long with a banner on the team's page. Photos are compressed in the browser before upload. A photo captured before the hunt ended is still accepted for 15 minutes after the end (`Hunt::LATE_UPLOAD_GRACE`) so slow connections do not lose last-minute finds.

### Videos

Phones upload whatever they record (iPhones send HEVC `.mov` files that many Android, Windows and Firefox browsers cannot play), so every video is converted on the worker by `TranscodeVideoJob` into an H.264 MP4 (high profile, level 4.2, at most 1920×1080 and 60 fps) and attached as `Submission#playback`, with a poster frame generated at the same time. The original stays attached as `photo` for the archive; `Submission#media_url` serves the playable version once it exists and the original until then, and the checklist shows "Processing video" in the meantime. The job probes every upload first (ignoring any metadata the client sent) and refuses clips over the limit or ones that did not upload completely by purging the photo and sending a banner over the team's submissions stream. ffmpeg and ffprobe only ever run through `VideoTranscoder.run`, which restricts them to plain files and the mov/mp4, matroska and webm demuxers and kills them after ten minutes. `bin/rails videos:transcode_missing` queues the conversion for videos uploaded before this existed.

The conversion needs ffmpeg and ffprobe. Render has no package manager, so `bin/install-ffmpeg` downloads a pinned static Linux build into `vendor/ffmpeg/` during both the web and worker builds (checked against its SHA-256) and production points `config.active_storage.paths` at it. Development uses whatever is on `PATH` (`brew install ffmpeg`); without it videos still upload but are never converted. The test suite never runs the real programs: `spec/support/bin/` holds stand-ins that copy a fixture and print canned probe output.

### Push notifications

Phones that installed the app and allowed notifications get a push when a hunt is five minutes from starting, when it is over and the results are up, when the photo show starts and when a new team takes the lead. Pushes are signed with VAPID keys from the Rails credentials. Generate a pair once:

```bash
bin/rails runner 'key = WebPush.generate_key; puts "public_key: #{key.public_key}", "private_key: #{key.private_key}"'
```

Then add them with `bin/rails credentials:edit`:

```yaml
vapid:
  subject: mailto:you@example.com
  public_key: <public key>
  private_key: <private key>
```

`VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` and `VAPID_SUBJECT` environment variables work too. Without keys the opt-in sheet and the notification settings stay hidden and nothing is sent. The test environment generates a throwaway pair at boot. Rotating the keys invalidates every existing subscription, so phones have to allow notifications again.

Subscriptions live in `push_subscriptions`, one per phone and hunt, keyed by the viewer's `user_id` cookie. Only endpoints on the browsers' own push services (Google, Mozilla, Apple, Microsoft; see `PushSubscription::PUSH_SERVICES`) are accepted, so the worker never posts to an address a viewer made up; add a browser's service there if its subscriptions are refused. Push services answer 404 or 410 for a phone that revoked its subscription; those rows are deleted the next time a notification goes out.

## Adding New Scavenger Hunt Templates

One of the features of Scavenger Hunt is ready made hunt templates. These are loaded in during app boot from `app/templates`. To create a new scavenger hunt template just make a new YAML file in `app/templates` that is structured like a `Hunt` model with associated `Category`s and `Item`s.

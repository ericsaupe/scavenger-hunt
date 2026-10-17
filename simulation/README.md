# Full hunt simulation

A Render-shaped copy of production in Docker Compose, plus Playwright bots that play an organizer, five teams on twelve phones, a big screen and a push service, through a whole hunt and show. It exists so the live-update paths (Turbo broadcasts over Solid Cable, web push, GoodJob) can be rehearsed under real concurrency before an event.

## What runs

| Service | What | Stands in for |
| --- | --- | --- |
| web | the app image in production mode, Puma, `WEB_CONCURRENCY=2`, capped at 1 CPU / 2 GB | scavenger_hunt_web |
| worker | same image, `good_job start`, `GOOD_JOB_THREADS=8`, 1 CPU / 2 GB | scavenger_hunt_worker |
| db | postgres:18, 0.5 CPU / 1 GB, also holds Solid Cable and Solid Cache | scavenger_hunt_db |
| minio | S3-compatible storage with the direct-upload CORS rule | the S3 bucket |
| caddy | TLS with a local CA for `www.scavengerhunt.party`, `storage.scavengerhunt.party` and `fcm.googleapis.com` | Render's edge |
| push | records and decrypts every web push the worker sends | FCM |

Browsers on the Mac reach the stack through Chrome host-resolver rules, so the app keeps its real hostname, `force_ssl`, host authorization and secure cookies. The worker resolves `fcm.googleapis.com` to the push stand-in through a Compose network alias and trusts Caddy's CA through `SSL_CERT_FILE`.

## Requirements

Docker Desktop (the image builds natively for arm64 with Debian's ffmpeg; `SIM_PLATFORM=linux/amd64` builds the Render-identical image with the static ffmpeg under Rosetta, about three times slower per request), Google Chrome, Node 22+, ffmpeg on the Mac for the fixture clips, and ports 80, 443, 3000 and 8081 free.

## Running it

```bash
cd simulation/bots && npm install
mkdir -p ../fixtures/photos && cp ../../tmp/demo_photos/*.jpg ../fixtures/photos/
ffmpeg -i ../../spec/fixtures/video.mp4 -t 20 -c copy ../fixtures/clip-20s.mp4
ffmpeg -stream_loop 3 -i ../../spec/fixtures/video.mp4 -t 70 -c copy ../fixtures/clip-70s.mp4
cd .. && ./simulate up
./simulate smoke
./simulate run
```

The photos come from `bin/rails demo:hunt`, which caches them in `tmp/demo_photos`. `simulate up` writes a `.env` with fresh VAPID keys and a secret key base; the production master key is never used.

A full run takes about 37 minutes and writes `results/<timestamp>/` with `events.jsonl` (every DOM observation and bot action), screenshots per role, `deliveries.json` from the push stand-in, `db.json`, container logs, `stats.csv` and a `summary.md` built by `bots/report.js`.

## Timeline

Minutes from the moment the organizer submits the create form: hunt starts at 7 and ends at 19, results are unlocked at 1 so the lead-change push can fire during the hunt, the show runs 21 to 33 with the web container restarted at 27, the finale at 33, the remote handed back and the zip downloaded at 34, the results-ready push at 34 (end plus the 15-minute grace window), and the chat feature flag flipped off and on at 35. `bots/plans.js` holds every phone's uploads, chat lines, votes and offline windows.

#!/usr/bin/env bash
set -euo pipefail
code="${1:?hunt code}"
cd "$(dirname "$0")/.."
echo "image: $(docker compose images web --format json | python3 -c 'import sys,json; d=json.load(sys.stdin); d=d[0] if isinstance(d,list) else d; print(d.get("Repository"), d.get("ID", "")[:12])') arch: $(docker compose exec -T web uname -m)"
echo "presenter page, 10 sequential GETs (seconds):"
for _ in $(seq 1 10); do
  curl -sk --resolve www.scavengerhunt.party:443:127.0.0.1 -o /dev/null -w '%{time_total}\n' "https://www.scavengerhunt.party/scavenger_hunts/$code/presenter?screen=big"
done | sort -n | awk '{a[NR]=$1} END {printf "  min %.3f median %.3f max %.3f\n", a[1], a[int((NR+1)/2)], a[NR]}'
echo "variant generation (large + small) for the first found photo, 3 runs:"
docker compose exec -T web bin/rails runner '

  hunt = Hunt.find_by!(code: ARGV[0])
  submission = hunt.submissions.found.detect { |s| !s.video? }
  3.times do
    ActiveStorage::VariantRecord.where(blob_id: submission.photo.blob.id).destroy_all
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC); submission.photo.variant(resize_to_fit: [1500, 1500], format: :jpg).processed; submission.photo.variant(resize_to_fit: [500, 500], format: :jpg).processed; t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    puts "  #{t.round(2)} s"
  end
' -- "$code" 2>/dev/null | grep -v "^$"

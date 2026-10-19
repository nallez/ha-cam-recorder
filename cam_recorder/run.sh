#!/bin/bash
set -u
OPTS=/data/options.json
RET_H=$(jq -r .retention_hours $OPTS)
SEG=$(jq -r .segment_seconds $OPTS)
REMOTE=$(jq -r .drive_remote $OPTS)
DPATH=$(jq -r .drive_path $OPTS)
INT=$(jq -r .upload_interval_seconds $OPTS)
RET_MIN=$((RET_H*60))
BASE=/media/cameras
export RCLONE_CONFIG=/config/rclone.conf   # add-on's own config dir (addon_config)

if [ ! -f "$RCLONE_CONFIG" ]; then
  echo "WARN: $RCLONE_CONFIG missing - recording locally only until you add it."
fi

record() {  # $1=name $2=url
  mkdir -p "$BASE/$1"
  while true; do
    ffmpeg -hide_banner -loglevel warning -rtsp_transport tcp -i "$2" \
      -c copy -f segment -segment_time "$SEG" -segment_atclocktime 1 \
      -reset_timestamps 1 -strftime 1 "$BASE/$1/%Y-%m-%d_%H-%M-%S.mkv"
    echo "[$1] ffmpeg exited, retrying in 10s"; sleep 10
  done
}

for i in $(seq 0 $(( $(jq '.cameras|length' $OPTS) - 1 ))); do
  N=$(jq -r ".cameras[$i].name" $OPTS); U=$(jq -r ".cameras[$i].url" $OPTS)
  record "$N" "$U" &
done

while true; do
  sleep "$INT"
  # local retention
  find "$BASE" -name '*.mkv' -mmin +"$RET_MIN" -delete
  [ -f "$RCLONE_CONFIG" ] || continue
  # skip files still being written (modified in last 2 min)
  rclone copy "$BASE" "$REMOTE:$DPATH" --min-age 2m --max-age "${RET_H}h" --transfers 2 \
    || echo "upload failed, will retry"
  rclone delete "$REMOTE:$DPATH" --min-age "${RET_H}h" || true
done

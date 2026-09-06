#!/usr/bin/env bash
set -euo pipefail

# Chromium native-messaging host for the yt-dlp companion extension
# (dedjgknigfeelejglamclffonmophnfl — see ../helium/default.nix). The
# extension sends {"url": "..."} down stdin on a length-prefixed frame; this
# downloads it with yt-dlp and notifies on completion.
#
# Trimmed from basecamp/omarchy's omarchy-chromium-ytdlp-host: dropped the
# omarchy-osd live progress bar (that's Hyprland-shell IPC this flake has no
# equivalent for) in exchange for a single "done" notification, same trade a
# plain `yt-dlp url` from a terminal already makes.

DOWNLOAD_DIR="$HOME/Videos"

parse_url() {
  jq -r '.url // empty' 2>/dev/null <<<"$1" || true
}

valid_url() {
  [[ $1 =~ ^https?:// ]]
}

# A path yt-dlp prints is only usable if it is a regular file inside
# DOWNLOAD_DIR — this is what stops a forged after_move record (a
# leading-dash mpv option, a path with control characters, or anything that
# escaped the download directory) from reaching the click-to-play exec below.
resolve_download_file() {
  local candidate=$1 file_real dir_real

  [[ -n $candidate ]] || return 1
  [[ $candidate != *$'\n'* && $candidate != *$'\r'* && $candidate != *$'\t'* ]] || return 1
  [[ -f $candidate ]] || return 1

  IFS= read -r -d '' file_real < <(realpath -ze -- "$candidate") || return 1
  IFS= read -r -d '' dir_real < <(realpath -ze -- "$DOWNLOAD_DIR") || return 1

  [[ $file_real != *$'\n'* && $file_real != *$'\r'* && $file_real != *$'\t'* ]] || return 1
  [[ $file_real == "${dir_real%/}"/* ]] || return 1

  printf '%s' "$file_real"
}

download_url() {
  local url="$1"

  mkdir -p "$DOWNLOAD_DIR"

  if ! yt-dlp --no-playlist --simulate --quiet --no-warnings -- "$url" >/dev/null 2>&1; then
    notify-send --app-name=ytdlp-download --icon=dialog-error "No video found for download" "$url"
    exit 0
  fi

  local filepath resolved title
  filepath=$(yt-dlp --no-playlist --no-simulate --quiet --no-warnings \
    --paths "$DOWNLOAD_DIR" -o '%(title)s.%(ext)s' \
    --print after_move:filepath -- "$url" 2>/dev/null | tail -n1) || filepath=""

  resolved=$(resolve_download_file "$filepath") || resolved=""

  if [[ -z $resolved ]]; then
    notify-send --app-name=ytdlp-download --icon=dialog-error "Download failed" "$url"
    exit 0
  fi

  title=${resolved##*/}
  title=${title%.*}
  ((${#title} > 50)) && title="${title:0:50}…"

  # Square, center-cropped thumbnail so the notification preview isn't
  # stretched. Best-effort: the download already succeeded, so a thumbnail
  # failure must not turn into a failure toast.
  local preview=""
  local candidate_preview
  candidate_preview=$(mktemp --suffix=.jpg)
  if ffmpeg -y -i "$resolved" -ss 00:00:00.1 -vframes 1 \
    -vf "crop='min(iw,ih)':'min(iw,ih)',scale=256:256" -q:v 2 \
    "$candidate_preview" -loglevel quiet 2>/dev/null \
    && [[ -s $candidate_preview ]]; then
    preview="$candidate_preview"
  else
    rm -f "$candidate_preview"
  fi

  # notify-send -A blocks until the notification is actioned or closed, then
  # prints the action key (verified against DMS — see ../android.nix, the
  # same pattern for "Show screen"). Bounded to 10 minutes so a toast nobody
  # touches cannot leave this process resident forever.
  local action
  action=$(timeout 600 notify-send \
    --app-name=ytdlp-download --icon="${preview:-video-x-generic}" \
    --action=play="Play" \
    "Download complete" "$title" || true)

  [[ -n $preview ]] && rm -f "$preview"

  # `--` keeps mpv from parsing a leading-dash filename as an option.
  [[ "$action" == "play" ]] && exec mpv -- "$resolved"

  exit 0
}

main() {
  local length payload url

  # Detached worker: this is what actually runs yt-dlp and fires the
  # notification, outside the native-messaging host's own lifetime.
  # download_url always exits, one way or another.
  [[ ${1:-} == "--download" ]] && download_url "$2"

  # Native messaging frame: 4-byte little-endian length prefix, then UTF-8 JSON.
  length=$(head -c4 | od -An -v -tu4 --endian=little | tr -d ' ')
  [[ -n ${length:-} ]] && ((length > 0)) || exit 0

  payload=$(head -c "$length")

  # Ack with an empty message so the extension's sendNativeMessage callback
  # resolves cleanly.
  printf '\x02\x00\x00\x00{}'

  url=$(parse_url "$payload")
  [[ -n $url ]] || exit 0
  valid_url "$url" || exit 0

  # Detach the download so this host exits promptly and frees the browser's
  # native-messaging port.
  setsid -f "$0" --download "$url" </dev/null >/dev/null 2>&1
}

main "$@"

#!/usr/bin/env bash
# Drives the Firebase Hosting preview channel that gates a live deploy.
#
# Split into subcommands so the workflow can put the browser suite between
# `deploy` and `promote`: the live channel only ever changes after the e2e tests
# have passed against these exact bytes. `firebase hosting:channel:release`
# publishes a preview channel verbatim, so what the suite checked is what ships.
#
# `deploy` prints the channel URL on stdout and its chatter on stderr, which is
# what lets the workflow capture the URL in a variable.
set -euo pipefail

entry_point="${FIREBASE_ENTRY_POINT:-firebase}"
project="${FIREBASE_PROJECT_ID:-vernet-app}"
channel="${HOSTING_PREVIEW_CHANNEL:-}"

log() { printf '%s\n' "$*" >&2; }

run_firebase() {
  # The config and .firebaserc live in the entry point, so firebase must run
  # from there. `--only hosting` is deliberately absent: on firebase-tools 13.x
  # it fails here with "Hosting site or target hosting not detected".
  (cd "$entry_point" && firebase "$@" --project "$project")
}

action="${1:-}"

case "$action" in
  deploy)
    [[ -n "$channel" ]] || { log "::error::HOSTING_PREVIEW_CHANNEL is required."; exit 1; }
    expires="${2:-60m}"

    # Preview channels need the Blaze plan; on Spark this is the call that says
    # so, which is why the raw output is echoed rather than swallowed by jq.
    if ! json="$(run_firebase hosting:channel:deploy "$channel" --expires "$expires" --json 2>/dev/null)"; then
      log "::error::Preview channel deploy failed for channel '$channel'."
      log "Check the plan supports preview channels and that the service account has Hosting Admin."
      exit 1
    fi

    url="$(printf '%s' "$json" | jq -r --arg p "$project" \
      '.result[$p].url // (.result | to_entries[0].value.url) // empty')"

    if [[ -z "$url" ]]; then
      log "::error::Could not read a channel URL from firebase-tools. Raw output:"
      printf '%s\n' "$json" >&2
      exit 1
    fi

    log "Preview channel deployed: $url"
    printf '%s\n' "$url"
    ;;

  await)
    url="${2:-}"
    [[ -n "$url" ]] || { log "::error::usage: $0 await <url>"; exit 1; }
    deadline=$((SECONDS + ${3:-300}))
    probe="$(mktemp)"
    trap 'rm -f "$probe"' EXIT
    # A freshly deployed channel first answers with a small not-ready body, which
    # reads as a navigation timeout in the suite rather than as what it is. curl
    # writes to a file instead of a pipe here because `grep -q` would close the
    # pipe and `pipefail` would turn a matching page into a failed iteration.
    until curl -fsS --max-time 15 "$url/" -o "$probe" 2>/dev/null \
      && grep -q "<title>Vernet" "$probe"; do
      if (( SECONDS >= deadline )); then
        log "::error::$url never served the landing page (last body was $(wc -c <"$probe" | tr -d ' ') bytes)."
        exit 1
      fi
      sleep 5
    done
    log "Preview channel is serving."
    ;;

  promote)
    [[ -n "$channel" ]] || { log "::error::HOSTING_PREVIEW_CHANNEL is required."; exit 1; }
    # firebase-tools has no `hosting:channel:release`; cloning the preview
    # channel's already-uploaded version onto live is what publishes those exact
    # bytes, so the suite cannot pass on one version and ship another.
    log "Cloning channel $channel onto live."
    run_firebase hosting:clone "$project:$channel" "$project:live"
    log "Live channel now serves the verified bytes."
    ;;

  cleanup)
    [[ -n "$channel" ]] || exit 0
    # Channels also expire on their own, so failing here is noise rather than a
    # reason to redden a job whose real work already passed.
    run_firebase hosting:channel:delete "$channel" --force --non-interactive \
      || log "Preview channel $channel was already gone."
    ;;

  *)
    log "usage: $0 <deploy|await|promote|cleanup>"
    exit 64
    ;;
esac

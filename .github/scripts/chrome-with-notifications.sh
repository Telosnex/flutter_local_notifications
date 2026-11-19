#!/usr/bin/env bash
set -euo pipefail

# Flutter's test and drive runners add --disable-notifications, which
# removes the Notification API that these tests exercise.
args=()
for arg in "$@"; do
  if [[ "$arg" != --disable-notifications ]]; then
    args+=("$arg")
  fi
done
exec google-chrome "${args[@]}"

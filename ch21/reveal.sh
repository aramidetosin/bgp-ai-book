#!/usr/bin/env bash
# Chapter 21: reveal the injected fault and its reference post-mortem.
cd "$(dirname "$0")"
N=$(cat .gameday-fault 2>/dev/null)
[ -z "$N" ] && { echo "No game-day fault is active. Run ./gameday.sh first."; exit 1; }
names=( "" "clean link failure" "gray failure (silent loss)" "flapping link" "route leak" "session authentication teardown" )
echo "=== Injected fault $N: ${names[$N]} ==="
cat "postmortems/fault${N}.md"

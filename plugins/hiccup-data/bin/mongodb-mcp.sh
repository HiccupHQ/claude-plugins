#!/bin/sh
# hiccup-data: starts the read-only MongoDB MCP server for one Claude session, and ends it with that session.
# No npx: npx resolved @latest again at every start (4-6 s), and a session that ended in that time (a short claude -p)
# left npm exec and the server running for ever, because the server misses the end of stdin while it starts.
# The pinned version is installed once, then run with node directly; mcp-watchdog.mjs ends it when its client goes.
V=3.1.0
HERE=$(cd "$(dirname "$0")" && pwd)
DIR="$HOME/.hiccup-data/mongodb-mcp-server-$V"
MAIN="$DIR/node_modules/mongodb-mcp-server/dist/esm/index.js"
if [ ! -f "$MAIN" ]; then
  # First start of this version (about 10 s; from the npm cache when it is there). Each start that finds no copy installs
  # its own, and the first to finish keeps it: a rename onto a directory that exists fails, so a copy never lands inside another.
  mkdir -p "$HOME/.hiccup-data"
  npm install --prefix "$DIR.$$" --no-audit --no-fund --omit=dev --no-package-lock --prefer-offline "mongodb-mcp-server@$V" >&2 \
    && node -e 'try { require("fs").renameSync(process.argv[1], process.argv[2]) } catch {}' "$DIR.$$" "$DIR"
  rm -rf "$DIR.$$"
fi
[ -f "$MAIN" ] || { echo "hiccup-data: could not install mongodb-mcp-server $V" >&2; exit 1; }
exec node --import "$HERE/mcp-watchdog.mjs" "$MAIN" "$@"

#!/bin/sh
# Sends one Claude Code hook event to the brain and prints its answer.
# Never fails a session: no token, no network or a slow brain prints nothing.
# A run nobody watches (claude -p from a script, a Fortress automation) does not
# use the brain: Claude Code marks it CLAUDE_CODE_SESSION_ATTENDED=0. Set
# BRAIN_HEADLESS=1 to give such a run the brain anyway.
if [ "$CLAUDE_CODE_SESSION_ATTENDED" = "0" ] && [ "$BRAIN_HEADLESS" != "1" ]; then cat >/dev/null; exit 0; fi
IN=$(cat)
D=$(printf '%s' "$IN" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$D" ] && cd "$D" 2>/dev/null
T=$(cat "${BRAIN_TOKEN_FILE:-$HOME/.brain/token}" 2>/dev/null)
U=${BRAIN_URL:-https://brain-production-9a93.up.railway.app}
ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
R=$(git remote get-url origin 2>/dev/null | sed -E 's#\.git$##; s#.*[/:]##')
[ -z "$R" ] && [ -n "$ROOT" ] && R=$(basename "$ROOT")
# BRAIN_AREAS (comma list) is set by a client such as Fortress: the areas this
# session works in, whose blueprints the launch pushes.
# Only the session id and the edited file's path leave this machine. Claude
# Code's event also holds the code of an edit; the brain needs none of it.
SID=$(printf '%s' "$IN" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
FILE=$(printf '%s' "$IN" | sed -nE 's/.*"tool_input"[[:space:]]*:[[:space:]]*\{[^}]*"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"([^"]*)".*/\2/p' | head -1)
printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$SID" "$FILE" | curl -s -m "${2:-5}" -X POST \
  -H "Authorization: Bearer $T" -H "X-Brain-Repo: $R" -H "X-Brain-Root: $ROOT" -H "X-Brain-Areas: $BRAIN_AREAS" \
  -H 'content-type: application/json' --data-binary @- "$U/hooks/$1" 2>/dev/null
exit 0

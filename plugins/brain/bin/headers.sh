#!/bin/sh
# Prints the auth header of the brain connector. Claude Code runs this from the
# plugin folder without the session's environment, so it carries the token only;
# the session passes its repo to the tools itself.
for F in "$BRAIN_TOKEN_FILE" "$CLAUDE_PLUGIN_ROOT/.token" "$HOME/.brain/token"; do
  [ -n "$F" ] && [ -r "$F" ] && { T=$(cat "$F"); break; }
done
printf '{"Authorization":"Bearer %s"}\n' "$T"

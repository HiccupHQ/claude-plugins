#!/bin/sh
# Opens MongoDB Compass logged in to Hiccup data. Started by "Hiccup Compass.app".
# Profile: hiccup-claude-analytics (read-only views), or the one in ~/.hiccup/compass-profile.
AWS=$(command -v aws 2>/dev/null || echo "$HOME/aws-cli/aws"); [ -x "$AWS" ] || AWS=/opt/homebrew/bin/aws; [ -x "$AWS" ] || AWS=/usr/local/bin/aws
PROFILE=$(cat "$HOME/.hiccup/compass-profile" 2>/dev/null || echo hiccup-claude-analytics)
"$AWS" sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1 || "$AWS" sso login --sso-session hiccup >/dev/null 2>&1
if [ "$PROFILE" = hiccup-claude-analytics ]; then
  URI='mongodb+srv://hiccup-prod.clqls.mongodb.net/?authMechanism=MONGODB-AWS&authSource=%24external&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS'
else
  URI='mongodb+srv://hiccup-prod.clqls.mongodb.net/?authMechanism=MONGODB-AWS&authSource=%24external'
fi
printf '%s' "$URI" | pbcopy
open --env AWS_PROFILE="$PROFILE" -a "MongoDB Compass" || osascript -e 'display alert "Hiccup Compass" message "Install MongoDB Compass first: mongodb.com/products/compass"'

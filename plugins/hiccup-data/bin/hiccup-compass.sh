#!/bin/sh
# Opens MongoDB Compass logged in to Hiccup data. Started by "Hiccup Compass.app".
# Profile: hiccup-mongo-admin (read/write) when the person has MongoProdAdmin, else hiccup-claude-analytics (read-only views).
AWS=$(command -v aws 2>/dev/null || echo "$HOME/aws-cli/aws"); [ -x "$AWS" ] || AWS=/opt/homebrew/bin/aws; [ -x "$AWS" ] || AWS=/usr/local/bin/aws
grep -q '\[profile hiccup-mongo-admin\]' "$HOME/.aws/config" 2>/dev/null || printf '\n[profile hiccup-mongo-admin]\nsso_session = hiccup\nsso_account_id = 310852620549\nsso_role_name = MongoProdAdmin\nregion = eu-west-2\n' >> "$HOME/.aws/config"
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || "$AWS" sso login --sso-session hiccup >/dev/null 2>&1
# Read/write for people with the MongoProdAdmin role; read-only views for everyone else.
PROFILE=hiccup-claude-analytics
"$AWS" sts get-caller-identity --profile hiccup-mongo-admin >/dev/null 2>&1 && PROFILE=hiccup-mongo-admin
if [ "$PROFILE" = hiccup-claude-analytics ]; then
  URI='mongodb+srv://hiccup-prod.clqls.mongodb.net/?authMechanism=MONGODB-AWS&authSource=%24external&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS'
else
  URI='mongodb+srv://hiccup-prod.clqls.mongodb.net/?authMechanism=MONGODB-AWS&authSource=%24external'
fi
printf '%s' "$URI" | pbcopy
open --env AWS_PROFILE="$PROFILE" -a "MongoDB Compass" || osascript -e 'display alert "Hiccup Compass" message "Install MongoDB Compass first: mongodb.com/products/compass"'

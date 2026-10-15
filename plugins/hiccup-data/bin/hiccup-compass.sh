#!/bin/sh
# Opens MongoDB Compass logged in to Hiccup data. Started by "Hiccup Compass.app".
# Profile: hiccup-mongo-admin (read/write) when the person has MongoProdAdmin, else hiccup-claude-analytics (read-only views).
AWS=$(command -v aws 2>/dev/null || echo "$HOME/aws-cli/aws"); [ -x "$AWS" ] || AWS=/opt/homebrew/bin/aws; [ -x "$AWS" ] || AWS=/usr/local/bin/aws
grep -q '\[profile hiccup-mongo-admin\]' "$HOME/.aws/config" 2>/dev/null || printf '\n[profile hiccup-mongo-admin]\nsso_session = hiccup\nsso_account_id = 310852620549\nsso_role_name = MongoProdAdmin\nregion = eu-west-2\n' >> "$HOME/.aws/config"
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || "$AWS" sso login --sso-session hiccup >/dev/null 2>&1
# Read/write for people with the MongoProdAdmin role; read-only views for everyone else.
# With "dev" as the first argument: the dev cluster, with the dev AdministratorAccess role.
HOST=hiccup-prod.clqls.mongodb.net
PROFILE=hiccup-claude-analytics
"$AWS" sts get-caller-identity --profile hiccup-mongo-admin >/dev/null 2>&1 && PROFILE=hiccup-mongo-admin
if [ "$1" = dev ]; then
  grep -q '\[profile hiccup-dev-data\]' "$HOME/.aws/config" || printf '\n[profile hiccup-dev-data]\nsso_session = hiccup\nsso_account_id = 186923665223\nsso_role_name = AdministratorAccess\nregion = eu-west-2\n' >> "$HOME/.aws/config"
  "$AWS" sts get-caller-identity --profile hiccup-dev-data >/dev/null 2>&1 || { osascript -e 'display alert "Hiccup Compass" message "You have no dev access. Ask Ronny."' >/dev/null 2>&1; exit 0; }
  HOST=hiccup-dev.gf4m4d.mongodb.net; PROFILE=hiccup-dev-data
fi
eval "$("$AWS" configure export-credentials --profile "$PROFILE" --format env)"
# Compass cannot read the SSO login, so the connection string carries the temporary keys (valid until the login ends).
OPTS='authMechanism=MONGODB-AWS&authSource=%24external'
[ "$PROFILE" = hiccup-claude-analytics ] && OPTS="$OPTS&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS"
enc() { printf '%s' "$1" | /usr/bin/sed -e 's/%/%25/g' -e 's#/#%2F#g' -e 's/+/%2B/g' -e 's/=/%3D/g' -e 's/:/%3A/g' -e 's/@/%40/g'; }
printf 'mongodb+srv://%s:%s@%s/?%s&authMechanismProperties=AWS_SESSION_TOKEN:%s' \
  "$(enc "$AWS_ACCESS_KEY_ID")" "$(enc "$AWS_SECRET_ACCESS_KEY")" "$HOST" "$OPTS" "$(enc "$AWS_SESSION_TOKEN")" | pbcopy
open -a "MongoDB Compass" 2>/dev/null || osascript -e 'display alert "Hiccup Compass" message "Install MongoDB Compass first: mongodb.com/products/compass"'

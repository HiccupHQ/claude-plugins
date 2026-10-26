#!/bin/sh
# Opens MongoDB Compass logged in to Hiccup data. Started by "Hiccup Compass.app" and /hiccup-data:compass.
# The role, best first (docs/architecture/data-access.md in hiccup-backend):
#   AdministratorAccess          read/write on everything                       profile hiccup-mongo-admin
#   MongoWrite<Scope>            read/write on that scope, read on the rest     profile hiccup-mongo-write-<scope>
#   ClaudeFinance                read-only views and HR expenses                profile hiccup-claude-finance
#   ClaudeAnalytics              read-only views                                profile hiccup-claude-analytics
# A scope as the first argument (catalog, orders, supply, ops, storefront, finance, reports, hr, cms) asks for that
# write set; a person gets one for a period through a line in hiccup-backend framework/sso-access/grants.json.
# "dev" as the first argument: the dev cluster, with the dev AdministratorAccess role.
# HICCUP_COMPASS_DRY=1 prints the chosen role and opens nothing.
AWS=$(command -v aws 2>/dev/null || echo "$HOME/aws-cli/aws"); [ -x "$AWS" ] || AWS=/opt/homebrew/bin/aws; [ -x "$AWS" ] || AWS=/usr/local/bin/aws
CONFIG="$HOME/.aws/config"; mkdir -p "$HOME/.aws"; touch "$CONFIG"
ACCOUNT=310852620549
SCOPES="catalog orders supply ops storefront finance reports hr cms"
cap() { printf '%s' "$1" | /usr/bin/awk '{print toupper(substr($0,1,1)) substr($0,2)}'; }
alert() { [ "$HICCUP_COMPASS_DRY" = 1 ] && { echo "$1"; return; }; /usr/bin/osascript -e "display alert \"Hiccup Compass\" message \"$1\"" >/dev/null 2>&1; }
profile() { grep -q "^\[profile $1\]" "$CONFIG" || printf '\n[profile %s]\nsso_session = hiccup\nsso_account_id = %s\nsso_role_name = %s\nregion = eu-west-2\n' "$1" "$ACCOUNT" "$2" >> "$CONFIG"; }
# hiccup-mongo-admin was MongoProdAdmin, a set retired on 2026-10-26: it is AdministratorAccess now.
/usr/bin/awk '/^\[/{inp=($0=="[profile hiccup-mongo-admin]")} inp && /^sso_role_name/{$0="sso_role_name = AdministratorAccess"} {print}' "$CONFIG" > "$CONFIG.hiccup" \
  && { cmp -s "$CONFIG" "$CONFIG.hiccup" || mv "$CONFIG.hiccup" "$CONFIG"; }
rm -f "$CONFIG.hiccup"
profile hiccup-mongo-admin AdministratorAccess
profile hiccup-claude-finance ClaudeFinance
profile hiccup-claude-analytics ClaudeAnalytics
for s in $SCOPES; do profile "hiccup-mongo-write-$s" "MongoWrite$(cap "$s")"; done
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || "$AWS" sso login --sso-session hiccup >/dev/null 2>&1
# The roles the person holds in the prod account, from the login's cached token in one call;
# when that fails (a stale cache file), by trying each profile.
held() {
  T=$(grep -l '"accessToken"' "$HOME"/.aws/sso/cache/*.json 2>/dev/null | xargs grep -l '"startUrl": *"https://d-9c677602a8.awsapps.com/start"' 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
  TOKEN=$(sed -n 's/.*"accessToken": *"\([^"]*\)".*/\1/p' "$T" 2>/dev/null | head -1)
  ROLES=$([ -n "$TOKEN" ] && "$AWS" sso list-account-roles --account-id "$ACCOUNT" --region eu-west-2 --access-token "$TOKEN" --query 'roleList[].roleName' --output text 2>/dev/null | tr '\t' ' ')
  if [ -z "$ROLES" ]; then
    for p in hiccup-mongo-admin:AdministratorAccess hiccup-claude-finance:ClaudeFinance hiccup-claude-analytics:ClaudeAnalytics; do
      "$AWS" sts get-caller-identity --profile "${p%%:*}" >/dev/null 2>&1 && ROLES="$ROLES ${p#*:}"
    done
    for s in $SCOPES; do "$AWS" sts get-caller-identity --profile "hiccup-mongo-write-$s" >/dev/null 2>&1 && ROLES="$ROLES MongoWrite$(cap "$s")"; done
  fi
  printf ' %s ' "$ROLES"
}
HELD=$(held)
has() { case "$HELD" in *" $1 "*) return 0 ;; esac; return 1; }
HOST=hiccup-prod.clqls.mongodb.net
PROFILE=; WANT=$1
if [ "$WANT" = dev ]; then
  profile_dev='[profile hiccup-dev-data]'
  grep -q "^$profile_dev" "$CONFIG" || printf '\n%s\nsso_session = hiccup\nsso_account_id = 186923665223\nsso_role_name = AdministratorAccess\nregion = eu-west-2\n' "$profile_dev" >> "$CONFIG"
  "$AWS" sts get-caller-identity --profile hiccup-dev-data >/dev/null 2>&1 || { alert "You have no dev access. Ask Ronny."; exit 0; }
  HOST=hiccup-dev.gf4m4d.mongodb.net; PROFILE=hiccup-dev-data; ROLE="dev AdministratorAccess (read/write on the dev cluster)"
elif [ -n "$WANT" ]; then
  case " $SCOPES " in *" $WANT "*) ;; *) alert "Unknown scope '$WANT'. One of: $SCOPES, or dev."; exit 0 ;; esac
  if has "MongoWrite$(cap "$WANT")"; then PROFILE="hiccup-mongo-write-$WANT"; ROLE="MongoWrite$(cap "$WANT") (read/write on the $WANT collections, read on the rest)"
  elif has AdministratorAccess; then PROFILE=hiccup-mongo-admin; ROLE="AdministratorAccess (read/write on everything; it covers $WANT)"
  else alert "You hold no write grant on $WANT. Ask for a MongoWrite$(cap "$WANT") line in hiccup-backend framework/sso-access/grants.json, with an until date."; exit 0
  fi
else
  if has AdministratorAccess; then PROFILE=hiccup-mongo-admin; ROLE="AdministratorAccess (read/write on everything)"
  else
    for s in $SCOPES; do has "MongoWrite$(cap "$s")" && { PROFILE="hiccup-mongo-write-$s"; ROLE="MongoWrite$(cap "$s") (read/write on the $s collections, read on the rest)"; break; }; done
  fi
  [ -z "$PROFILE" ] && has ClaudeFinance && { PROFILE=hiccup-claude-finance; ROLE="ClaudeFinance (read-only views and HR expenses)"; }
  [ -z "$PROFILE" ] && { PROFILE=hiccup-claude-analytics; ROLE="ClaudeAnalytics (read-only views)"; }
fi
echo "Compass as $ROLE."
[ "$HICCUP_COMPASS_DRY" = 1 ] && { echo "profile $PROFILE on $HOST; held:$HELD"; exit 0; }
eval "$("$AWS" configure export-credentials --profile "$PROFILE" --format env)"
# Compass cannot read the SSO login, so the connection string carries the temporary keys (valid until the login ends).
OPTS='authMechanism=MONGODB-AWS&authSource=%24external'
case "$PROFILE" in hiccup-claude-analytics|hiccup-claude-finance) OPTS="$OPTS&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS" ;; esac
enc() { printf '%s' "$1" | /usr/bin/sed -e 's/%/%25/g' -e 's#/#%2F#g' -e 's/+/%2B/g' -e 's/=/%3D/g' -e 's/:/%3A/g' -e 's/@/%40/g'; }
printf 'mongodb+srv://%s:%s@%s/?%s&authMechanismProperties=AWS_SESSION_TOKEN:%s' \
  "$(enc "$AWS_ACCESS_KEY_ID")" "$(enc "$AWS_SECRET_ACCESS_KEY")" "$HOST" "$OPTS" "$(enc "$AWS_SESSION_TOKEN")" | pbcopy
open -a "MongoDB Compass" 2>/dev/null || alert "Install MongoDB Compass first: mongodb.com/products/compass"

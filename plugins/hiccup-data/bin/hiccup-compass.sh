#!/bin/sh
# Opens MongoDB Compass logged in to Hiccup data. Started by "Hiccup Compass.app".
# Prod role, the first one the person holds: AdministratorAccess (read/write every database), MongoWrite<Scope>
# (read/write one domain, a grant with an end date in hiccup-backend framework/sso-access/grants.json),
# FinanceRead (read-only views and HR expenses), AnalyticsRead (read-only views).
# A scope as the first argument (catalog, orders, supply, ops, storefront, finance, reports, hr, cms) asks for MongoWrite<Scope>.
# With "dev" as the first argument: the dev cluster, with the dev AdministratorAccess role.
AWS=$(command -v aws 2>/dev/null || echo "$HOME/aws-cli/aws"); [ -x "$AWS" ] || AWS=/opt/homebrew/bin/aws; [ -x "$AWS" ] || AWS=/usr/local/bin/aws
PROD_ACCOUNT=310852620549
add_profile() { grep -q "\[profile $1\]" "$HOME/.aws/config" 2>/dev/null || printf '\n[profile %s]\nsso_session = hiccup\nsso_account_id = %s\nsso_role_name = %s\nregion = eu-west-2\n' "$1" "$2" "$3" >> "$HOME/.aws/config"; }
alert() { echo "$1"; osascript -e "display alert \"Hiccup Compass\" message \"$1\"" >/dev/null 2>&1; }
add_profile hiccup-claude-analytics "$PROD_ACCOUNT" AnalyticsRead
# The data profiles were ClaudeAnalytics and ClaudeFinance before 2026-10-26: they read with AnalyticsRead and FinanceRead now.
/usr/bin/awk '/^\[/{set=""; if ($0=="[profile hiccup-claude-analytics]") set="AnalyticsRead"; if ($0=="[profile hiccup-claude-finance]") set="FinanceRead"}
  set!="" && /^sso_role_name/{$0="sso_role_name = " set} {print}' "$HOME/.aws/config" > "$HOME/.aws/config.hiccup.$$" \
  && { cmp -s "$HOME/.aws/config" "$HOME/.aws/config.hiccup.$$" || mv "$HOME/.aws/config.hiccup.$$" "$HOME/.aws/config"; }
rm -f "$HOME/.aws/config.hiccup.$$"
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || "$AWS" sso login --sso-session hiccup >/dev/null 2>&1
HOST=hiccup-prod.clqls.mongodb.net
if [ "$1" = dev ]; then
  add_profile hiccup-dev-data 186923665223 AdministratorAccess
  "$AWS" sts get-caller-identity --profile hiccup-dev-data >/dev/null 2>&1 || { alert "You have no dev access. Ask Ronny."; exit 0; }
  HOST=hiccup-dev.gf4m4d.mongodb.net; ROLE=AdministratorAccess; PROFILE=hiccup-dev-data
else
  # The prod roles this person holds, read with the SSO login (its cache file is the SHA-1 of the session name).
  TOKEN=$(/usr/bin/plutil -extract accessToken raw -o - "$HOME/.aws/sso/cache/$(printf hiccup | /usr/bin/shasum | cut -c1-40).json" 2>/dev/null)
  ROLES=" $("$AWS" sso list-account-roles --access-token "$TOKEN" --account-id "$PROD_ACCOUNT" --region eu-west-2 \
    --query 'roleList[].roleName' --output text 2>/dev/null | tr '\t' ' ') "
  WRITE_ROLES=$(printf '%s\n' $ROLES | grep '^MongoWrite')
  if [ -n "$1" ]; then
    SCOPE=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    ROLE=MongoWrite$(printf '%s' "$SCOPE" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$SCOPE" | cut -c2-)
    case "$ROLES" in *" $ROLE "*) ;; *) alert "You have no $SCOPE write access ($ROLE). Ask Ronny for a grant."; exit 0 ;; esac
  else
    case "$ROLES" in
      *" AdministratorAccess "*) ROLE=AdministratorAccess ;;
      *" MongoWrite"*) ROLE=$(printf '%s\n' $WRITE_ROLES | head -1) ;;
      *" FinanceRead "*) ROLE=FinanceRead ;;
      *) ROLE=AnalyticsRead ;;
    esac
  fi
  case "$ROLE" in
    AdministratorAccess) PROFILE=hiccup-prod-data ;;
    MongoWrite*) PROFILE=hiccup-mongo-write-$(printf '%s' "${ROLE#MongoWrite}" | tr '[:upper:]' '[:lower:]') ;;
    FinanceRead) PROFILE=hiccup-claude-finance ;;
    *) PROFILE=hiccup-claude-analytics ;;
  esac
  add_profile "$PROFILE" "$PROD_ACCOUNT" "$ROLE"
fi
eval "$("$AWS" configure export-credentials --profile "$PROFILE" --format env)"
# Compass cannot read the SSO login, so the connection string carries the temporary keys (valid until the login ends).
OPTS='authMechanism=MONGODB-AWS&authSource=%24external'
case "$ROLE" in AnalyticsRead|FinanceRead) OPTS="$OPTS&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS" ;; esac
enc() { printf '%s' "$1" | /usr/bin/sed -e 's/%/%25/g' -e 's#/#%2F#g' -e 's/+/%2B/g' -e 's/=/%3D/g' -e 's/:/%3A/g' -e 's/@/%40/g'; }
printf 'mongodb+srv://%s:%s@%s/?%s&authMechanismProperties=AWS_SESSION_TOKEN:%s' \
  "$(enc "$AWS_ACCESS_KEY_ID")" "$(enc "$AWS_SECRET_ACCESS_KEY")" "$HOST" "$OPTS" "$(enc "$AWS_SESSION_TOKEN")" | pbcopy
echo "Compass role: $ROLE"
[ -z "$1" ] && [ -n "$WRITE_ROLES" ] && echo "Write roles you hold: $(echo $WRITE_ROLES)"
open -a "MongoDB Compass" 2>/dev/null || osascript -e 'display alert "Hiccup Compass" message "Install MongoDB Compass first: mongodb.com/products/compass"'

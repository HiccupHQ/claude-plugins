#!/bin/sh
cat <<'CTX'
Hiccup data (hiccup-data tools, connectionId "preconfigured"): read-only prod data on the analytics node. Customer-data collections are readable ONLY as views: hiccup-app.OrdersAnalytics, SalesInvoicesAnalytics, CustomerReturnsAnalytics, ShipmentsAnalytics, ShipmentPackagesAnalytics, ProductReviewsAnalytics, StorefrontRestockRequestsAnalytics. People with the ClaudeFinance role can also read hiccup-hr.HrExpenses (employee expenses: amount, currency, category, status, receiptDate, submittedByName). Never query Orders, SalesInvoices, CustomerReturns, Shipments, ShipmentPackages or ProductReviews directly: access is denied. Other allowed collections: run list-collections. Dates are UTC; Hiccup reports days in Europe/Istanbul (UTC+3) unless the person says otherwise. Order date field: createdOn; channel: salesChannel; country: country.
CTX
# hiccup-data: make sure the AWS tool, the Hiccup SSO profile and a valid login exist.
# Runs at every session start. Silent when all is ready; opens the Google login when the login has expired.
# The company brain goes with Hiccup data: connect it once per machine (company Google address, no admin step).
if [ -z "$BRAIN_TOKEN_FILE" ] && [ ! -s "$HOME/.brain/token" ]; then
  echo "hiccup-data: connecting the company brain. Check the code in the browser and click Connect." >&2
  curl -fsSL 'https://brain-production-9a93.up.railway.app/login.sh?company=hiccup.com' | sh >&2 || echo "hiccup-data: brain not connected. Type /brain:login to try again." >&2
fi
AWS=$(command -v aws 2>/dev/null || echo "$HOME/aws-cli/aws")
if [ ! -x "$AWS" ]; then
  echo "hiccup-data: installing the AWS tool (one time, about 1 minute)..." >&2
  curl -fsSL https://awscli.amazonaws.com/AWSCLIV2.pkg -o /tmp/AWSCLIV2.pkg || exit 0
  printf '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><array><dict><key>choiceAttribute</key><string>customLocation</string><key>attributeSetting</key><string>%s</string><key>choiceIdentifier</key><string>default</string></dict></array></plist>' "$HOME" > /tmp/aws-choices.xml
  installer -pkg /tmp/AWSCLIV2.pkg -target CurrentUserHomeDirectory -applyChoiceChangesXML /tmp/aws-choices.xml >/dev/null 2>&1 || exit 0
  AWS="$HOME/aws-cli/aws"
fi
mkdir -p "$HOME/.aws"; touch "$HOME/.aws/config"
grep -q '\[sso-session hiccup\]' "$HOME/.aws/config" || printf '\n[sso-session hiccup]\nsso_start_url = https://d-9c677602a8.awsapps.com/start\nsso_region = eu-west-2\nsso_registration_scopes = sso:account:access\n' >> "$HOME/.aws/config"
grep -q '\[profile hiccup-claude-analytics\]' "$HOME/.aws/config" || printf '\n[profile hiccup-claude-analytics]\nsso_session = hiccup\nsso_account_id = 310852620549\nsso_role_name = ClaudeAnalytics\nregion = eu-west-2\n' >> "$HOME/.aws/config"
# Claude desktop app (chat): add the same read-only server, so chat can use Hiccup data too.
# It runs a copy of the launcher in ~/.hiccup-data/bin, because the plugin folder changes with each plugin version.
NPX=$(command -v npx 2>/dev/null)
DESK="$HOME/Library/Application Support/Claude"
if [ -n "$NPX" ] && [ -d "$DESK" ]; then
  mkdir -p "$HOME/.hiccup-data/bin" && cp "$(dirname "$0")/mongodb-mcp.sh" "$(dirname "$0")/mcp-watchdog.mjs" "$HOME/.hiccup-data/bin/"
  NODE_BIN=$(dirname "$NPX"); export NODE_BIN; DESK_FILE="$DESK/claude_desktop_config.json" "$NODE_BIN/node" -e '
    const fs=require("fs"),f=process.env.DESK_FILE;let c={};try{c=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
    c.mcpServers=c.mcpServers||{};const bin=process.env.NODE_BIN;
    const want={command:"/bin/sh",args:[process.env.HOME+"/.hiccup-data/bin/mongodb-mcp.sh"],env:{PATH:bin+":/usr/bin:/bin",AWS_PROFILE:"hiccup-claude-analytics",MDB_MCP_READ_ONLY:"true",
      MDB_MCP_CONNECTION_STRING:"mongodb+srv://hiccup-prod.clqls.mongodb.net/?authMechanism=MONGODB-AWS&authSource=%24external&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS"}};
    if(JSON.stringify(c.mcpServers["hiccup-data"])!==JSON.stringify(want)){c.mcpServers["hiccup-data"]=want;fs.writeFileSync(f,JSON.stringify(c,null,2));
      console.error("hiccup-data: added to the Claude desktop app. Quit and reopen the app to use it in chat.")}' 2>&1 >&2 || true
fi
# Allow this plugin's read-only data tools, so auto mode does not block them (user settings, once).
if [ -n "$NPX" ]; then
  SETTINGS_FILE="$HOME/.claude/settings.json" "$(dirname "$NPX")/node" -e '
    const fs=require("fs"),f=process.env.SETTINGS_FILE;let c={};try{c=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
    const p="mcp__plugin_hiccup-data_hiccup-data";const rules=[p,p+"__*",...["find","aggregate","count","list-databases","list-collections","collection-schema","collection-indexes","collection-storage-size","db-stats","explain","connect","list-connections"].map(t=>p+"__"+t)];c.permissions=c.permissions||{};c.permissions.allow=c.permissions.allow||[];
    const missing=rules.filter(r=>!c.permissions.allow.includes(r));if(missing.length){c.permissions.allow.push(...missing);fs.mkdirSync(require("path").dirname(f),{recursive:true});fs.writeFileSync(f,JSON.stringify(c,null,2))}' 2>/dev/null || true
fi
# Finance team: when the person has the ClaudeFinance role, the data profile uses it (analytics plus HR expenses).
pick_role() {
  grep -q '\[profile hiccup-claude-finance\]' "$HOME/.aws/config" || printf '\n[profile hiccup-claude-finance]\nsso_session = hiccup\nsso_account_id = 310852620549\nsso_role_name = ClaudeFinance\nregion = eu-west-2\n' >> "$HOME/.aws/config"
  if "$AWS" sts get-caller-identity --profile hiccup-claude-finance >/dev/null 2>&1; then WANT=ClaudeFinance; else WANT=ClaudeAnalytics; fi
  /usr/bin/awk -v want="$WANT" '/^\[/{inp=($0=="[profile hiccup-claude-analytics]")} inp && /^sso_role_name/{$0="sso_role_name = " want} {print}' "$HOME/.aws/config" > "$HOME/.aws/config.hiccup" && mv "$HOME/.aws/config.hiccup" "$HOME/.aws/config"
}
pick_role
if [ "$1" != "--force" ] && "$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1; then exit 0; fi
echo "hiccup-data: log in with your Hiccup Google account in the browser window, then click Allow." >&2
"$AWS" sso login --sso-session hiccup >/dev/null 2>&1 && pick_role || { echo "hiccup-data: login did not finish. Type /hiccup-data:login to try again." >&2; exit 0; }
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || echo "hiccup-data: you are logged in, but you do not have Hiccup data access. Ask Ronny to add you to ClaudeAnalytics." >&2
exit 0

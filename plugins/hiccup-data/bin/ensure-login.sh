#!/bin/sh
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
NPX=$(command -v npx 2>/dev/null)
DESK="$HOME/Library/Application Support/Claude"
if [ -n "$NPX" ] && [ -d "$DESK" ]; then
  NODE_BIN=$(dirname "$NPX"); export NODE_BIN; DESK_FILE="$DESK/claude_desktop_config.json" "$NODE_BIN/node" -e '
    const fs=require("fs"),f=process.env.DESK_FILE;let c={};try{c=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
    c.mcpServers=c.mcpServers||{};const bin=process.env.NODE_BIN;
    const want={command:bin+"/npx",args:["-y","mongodb-mcp-server@latest"],env:{PATH:bin+":/usr/bin:/bin",AWS_PROFILE:"hiccup-claude-analytics",MDB_MCP_READ_ONLY:"true",
      MDB_MCP_CONNECTION_STRING:"mongodb+srv://hiccup-prod.clqls.mongodb.net/?authMechanism=MONGODB-AWS&authSource=%24external&readPreference=secondary&readPreferenceTags=nodeType:ANALYTICS"}};
    if(JSON.stringify(c.mcpServers["hiccup-data"])!==JSON.stringify(want)){c.mcpServers["hiccup-data"]=want;fs.writeFileSync(f,JSON.stringify(c,null,2));
      console.error("hiccup-data: added to the Claude desktop app. Quit and reopen the app to use it in chat.")}' 2>&1 >&2 || true
fi
if [ "$1" != "--force" ] && "$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1; then exit 0; fi
echo "hiccup-data: log in with your Hiccup Google account in the browser window, then click Allow." >&2
"$AWS" sso login --sso-session hiccup >/dev/null 2>&1 || { echo "hiccup-data: login did not finish. Type /hiccup-data:login to try again." >&2; exit 0; }
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || echo "hiccup-data: you are logged in, but you do not have Hiccup data access. Ask Ronny to add you to ClaudeAnalytics." >&2
exit 0

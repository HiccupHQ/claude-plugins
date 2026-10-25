#!/bin/sh
# hiccup-data: make sure hx (the QueryGateway CLI), the AWS tool, the Hiccup SSO profile and a valid login exist.
# Runs at every session start. Silent when all is ready; opens the Google login when the login has expired.
# The company brain goes with Hiccup data: connect it once per machine (company Google address, no admin step).
if [ -z "$BRAIN_TOKEN_FILE" ] && [ ! -s "$HOME/.brain/token" ]; then
  echo "hiccup-data: connecting the company brain. Check the code in the browser and click Connect." >&2
  curl -fsSL 'https://brain-production-9a93.up.railway.app/login.sh?company=hiccup.com' | sh >&2 || echo "hiccup-data: brain not connected. Type /brain:login to try again." >&2
fi
# hx: a pinned build (HiccupHQ/claude-plugins release hx-13513f7), used only when its SHA-256 is the one below.
# It lives in ~/.hiccup-data/bin, because the plugin folder changes with each plugin version.
BIN="$HOME/.hiccup-data/bin"
HX_URL=https://github.com/HiccupHQ/claude-plugins/releases/download/hx-13513f7/hx-aarch64-apple-darwin
HX_SHA=b7b4c61305a283459111ef90544794e558d76dc6ee3207fd5e01afec97c7ea4d
sha_of() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }
# Apple silicon only; hw.optional.arm64 is 1 there in a Rosetta shell too.
if [ "$(uname -s)" != Darwin ] || [ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null)" != 1 ]; then
  echo "hiccup-data: hx runs only on Apple silicon Macs, so this machine reads no Hiccup data. Ask Ronny." >&2
elif [ "$(sha_of "$BIN/hx")" != "$HX_SHA" ]; then
  mkdir -p "$BIN"
  if curl -fsSL --connect-timeout 10 --max-time 120 "$HX_URL" -o "$BIN/hx.$$" && [ "$(sha_of "$BIN/hx.$$")" = "$HX_SHA" ]; then
    chmod +x "$BIN/hx.$$" && mv -f "$BIN/hx.$$" "$BIN/hx"
  else
    rm -f "$BIN/hx.$$"; echo "hiccup-data: could not install hx. Type /hiccup-data:login to try again." >&2
  fi
fi
# The Mongo MCP server (0.12.0 and older) is gone: remove its copies, its install and its entry in the desktop app.
rm -rf "$BIN/mongodb-mcp.sh" "$BIN/mcp-watchdog.mjs" "$HOME"/.hiccup-data/mongodb-mcp-server-*
/usr/bin/osascript -l JavaScript "$(dirname "$0")/settings.js" "$HOME" >&2 || true
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
# The QueryGateway knows the ClaudeAnalytics role, not ClaudeFinance; 0.12.0 put ClaudeFinance on this profile for the finance team.
/usr/bin/awk '/^\[/{inp=($0=="[profile hiccup-claude-analytics]")} inp && /^sso_role_name/{$0="sso_role_name = ClaudeAnalytics"} {print}' "$HOME/.aws/config" > "$HOME/.aws/config.hiccup" \
  && { cmp -s "$HOME/.aws/config" "$HOME/.aws/config.hiccup" || mv "$HOME/.aws/config.hiccup" "$HOME/.aws/config"; }
rm -f "$HOME/.aws/config.hiccup"
if [ -x "$BIN/hx" ]; then
  # Later Bash commands of this session find hx; a person's own hx earlier on PATH comes first.
  # Without an engineer's hiccup-prod profile, hx --env prod reads as ClaudeAnalytics.
  if [ -n "$CLAUDE_ENV_FILE" ]; then
    echo "export PATH=\"\$PATH:$BIN\"" >> "$CLAUDE_ENV_FILE"
    [ -z "$HICCUP_PROD_AWS_PROFILE" ] && ! grep -q '^\[profile hiccup-prod\]' "$HOME/.aws/config" \
      && echo "export HICCUP_PROD_AWS_PROFILE=hiccup-claude-analytics" >> "$CLAUDE_ENV_FILE"
  fi
  # A Fortress session gets its own hx text.
  [ -z "$FORTRESS_SESSION_ID" ] && cat <<'CTX'
Hiccup data: read it with hx, the QueryGateway CLI, in the Bash tool. Pass --env prod for Hiccup's real data (without it hx reads dev). hx only reads; never use mongosh.
- `hx --env prod describe` lists the collections and the fields you may read.
- `hx --env prod search <Collection> <field=value|field:in=a,b|field:after=2026-09-01|field:exists>.. [--fields a,b] [--sort -field] [--limit N] [--count]`
- `hx --env prod aggregate <Collection> <filters>.. [--by field|field:day|week|month] [--sum|--avg|--min|--max field].. [--unwind array] [--tz Europe/Istanbul] [--sort -count] [--limit N]` counts, sums or groups.
A filter takes any field describe lists; on a collection with a search index one filter must be a search field (describe lists them under filters). A read that is too large is refused and names the count: split a long date range by month and add the answers. Dates are UTC; Hiccup reports days in Europe/Istanbul unless the person says otherwise. Order date field: createdOn; channel: salesChannel; country: country.
CTX
fi
if [ "$1" != "--force" ] && "$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1; then exit 0; fi
echo "hiccup-data: log in with your Hiccup Google account in the browser window, then click Allow." >&2
"$AWS" sso login --sso-session hiccup >/dev/null 2>&1 || { echo "hiccup-data: login did not finish. Type /hiccup-data:login to try again." >&2; exit 0; }
"$AWS" sts get-caller-identity --profile hiccup-claude-analytics >/dev/null 2>&1 || echo "hiccup-data: you are logged in, but you do not have Hiccup data access. Ask Ronny to add you to ClaudeAnalytics." >&2
exit 0

#!/bin/sh
# hiccup-data: make sure hx (the QueryGateway CLI), the AWS tool, the Hiccup SSO profile and a valid login exist.
# Runs at every session start. Silent when all is ready; opens the Google login when the login has expired.
# The company brain goes with Hiccup data: connect it once per machine (company Google address, no admin step).
if [ -z "$BRAIN_TOKEN_FILE" ] && [ ! -s "$HOME/.brain/token" ]; then
  echo "hiccup-data: connecting the company brain. Check the code in the browser and click Connect." >&2
  curl -fsSL 'https://brain-production-9a93.up.railway.app/login.sh?company=hiccup.com' | sh >&2 || echo "hiccup-data: brain not connected. Type /brain:login to try again." >&2
fi
# hx: a pinned build (HiccupHQ/claude-plugins release hx-b589c4f), used only when its SHA-256 is the one below.
# It lives in ~/.hiccup-data/bin, because the plugin folder changes with each plugin version.
BIN="$HOME/.hiccup-data/bin"
HX_URL=https://github.com/HiccupHQ/claude-plugins/releases/download/hx-b589c4f/hx-aarch64-apple-darwin
HX_SHA=14698ffb3c5c1913ed55c263bce6c389e8ee7e09c0d0aebe5425cc6f49e4fd87
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
# The data profiles are named after their sets. The old names hiccup-claude-analytics and hiccup-claude-finance are
# not used: a Claude process started before 0.14.0 sets them back to the retired ClaudeAnalytics at each session start.
grep -q '\[profile hiccup-analytics-read\]' "$HOME/.aws/config" || printf '\n[profile hiccup-analytics-read]\nsso_session = hiccup\nsso_account_id = 310852620549\nsso_role_name = AnalyticsRead\nregion = eu-west-2\n' >> "$HOME/.aws/config"
grep -q '\[profile hiccup-finance-read\]' "$HOME/.aws/config" || printf '\n[profile hiccup-finance-read]\nsso_session = hiccup\nsso_account_id = 310852620549\nsso_role_name = FinanceRead\nregion = eu-west-2\n' >> "$HOME/.aws/config"
# The old profiles still point at the new sets, for a person who names them by hand (ClaudeAnalytics and
# ClaudeFinance before 2026-10-26; 0.12.0 put ClaudeFinance on hiccup-claude-analytics for the finance team).
/usr/bin/awk '/^\[/{set=""; if ($0=="[profile hiccup-claude-analytics]") set="AnalyticsRead"; if ($0=="[profile hiccup-claude-finance]") set="FinanceRead"}
  set!="" && /^sso_role_name/{$0="sso_role_name = " set} {print}' "$HOME/.aws/config" > "$HOME/.aws/config.hiccup.$$" \
  && { cmp -s "$HOME/.aws/config" "$HOME/.aws/config.hiccup.$$" || mv "$HOME/.aws/config.hiccup.$$" "$HOME/.aws/config"; }
rm -f "$HOME/.aws/config.hiccup.$$"
# The profile hx reads prod with: FinanceRead (analytics and HR expenses) for the finance team, else AnalyticsRead.
# Chosen after each login and kept in ~/.hiccup-data/read-profile, so a session start asks AWS once, not twice
# (~/.hiccup-data/reader is the old file, which a process started on 0.14.1 or older still writes).
READER="$HOME/.hiccup-data/read-profile"
pick_reader() {
  mkdir -p "$HOME/.hiccup-data"
  if "$AWS" sts get-caller-identity --profile hiccup-finance-read >/dev/null 2>&1; then echo hiccup-finance-read; else echo hiccup-analytics-read; fi > "$READER.$$" \
    && mv -f "$READER.$$" "$READER"
}
HX_OK=no; [ "$(sha_of "$BIN/hx")" = "$HX_SHA" ] && HX_OK=yes
# Later Bash commands of this session find hx; a person's own hx earlier on PATH comes first.
# Without an engineer's hiccup-prod profile, hx --env prod reads with the picked profile. The PATH and the
# profile known so far go out before the login, which can wait for the browser; a later export wins.
export_profile() {
  [ "$HX_OK" = yes ] && [ -n "$CLAUDE_ENV_FILE" ] && [ -z "$HICCUP_PROD_AWS_PROFILE" ] && ! grep -q '^\[profile hiccup-prod\]' "$HOME/.aws/config" || return 0
  PROFILE=hiccup-analytics-read; [ -s "$READER" ] && PROFILE=$(cat "$READER")
  echo "export HICCUP_PROD_AWS_PROFILE=$PROFILE" >> "$CLAUDE_ENV_FILE"
}
[ "$HX_OK" = yes ] && [ -n "$CLAUDE_ENV_FILE" ] && echo "export PATH=\"\$PATH:$BIN\"" >> "$CLAUDE_ENV_FILE"
export_profile
if [ "$1" != "--force" ] && "$AWS" sts get-caller-identity --profile hiccup-analytics-read >/dev/null 2>&1; then
  [ -s "$READER" ] || { pick_reader && export_profile; }
else
  # One login at a time: sessions that start together would each open a browser tab. The first takes the lock; the others wait for its login.
  LOCK="$HOME/.hiccup-data/login.lock"
  mkdir -p "$HOME/.hiccup-data"
  find "$LOCK" -maxdepth 0 -mmin +5 -exec rmdir {} \; 2>/dev/null
  if ! mkdir "$LOCK" 2>/dev/null; then
    WAITED=0
    while [ -d "$LOCK" ] && [ "$WAITED" -lt 300 ]; do sleep 2; WAITED=$((WAITED + 2)); done
    [ -s "$READER" ] || pick_reader
    export_profile
    exit 0
  fi
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  echo "hiccup-data: log in with your Hiccup Google account in the browser window, then click Allow." >&2
  if "$AWS" sso login --sso-session hiccup >/dev/null 2>&1; then
    pick_reader && export_profile
    "$AWS" sts get-caller-identity --profile hiccup-analytics-read >/dev/null 2>&1 || echo "hiccup-data: you are logged in, but you do not have Hiccup data access. Ask Ronny to add you to AnalyticsRead." >&2
  else
    echo "hiccup-data: login did not finish. Type /hiccup-data:login to try again." >&2
  fi
fi
if [ "$HX_OK" = yes ]; then
  # A Fortress session gets its own hx text.
  [ -z "$FORTRESS_SESSION_ID" ] && cat <<'CTX'
Hiccup data: read it with hx, the QueryGateway CLI, in the Bash tool. Pass --env prod for Hiccup's real data (without it hx reads dev). Use only hx describe, search and aggregate; never use mongosh.
- `hx --env prod describe` lists the collections and the fields you may read.
- `hx --env prod search <Collection> <field=value|field:in=a,b|field:after=2026-09-01|field:exists>.. [--fields a,b] [--sort -field] [--limit N] [--count]`
- `hx --env prod aggregate <Collection> <filters>.. [--by field|field:day|week|month] [--sum|--avg|--min|--max field].. [--unwind array] [--tz Europe/Istanbul] [--sort -count] [--limit N]` counts, sums or groups.
A filter takes any field describe lists; on a collection with a search index one filter must be a search field (describe lists them under filters). hx splits a too-large aggregate by date and adds the parts itself; a search that matches too much is refused and names the count, so narrow its filters. Dates are UTC; Hiccup reports days in Europe/Istanbul unless the person says otherwise. Order date field: createdOn; channel: salesChannel; country: country.
CTX
fi
exit 0

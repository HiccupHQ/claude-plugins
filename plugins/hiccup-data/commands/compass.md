---
description: Open MongoDB Compass logged in to Hiccup data with your best role (prod; add a scope such as "orders" for that write grant, or "dev" for the dev cluster). Copies the connection string.
allowed-tools: Bash
---
Run `sh "${CLAUDE_PLUGIN_ROOT}/bin/hiccup-compass.sh" $ARGUMENTS` with the Bash tool, with a timeout of 330000 ms.

The script prints the role it used: AdministratorAccess (read/write on everything), a MongoWrite<Scope> grant (read/write on that scope's collections, read on the rest), ClaudeFinance or ClaudeAnalytics (read-only views). A scope as the argument (catalog, orders, supply, ops, storefront, finance, reports, hr, cms) asks for that write grant; a person gets one for a period through one line in hiccup-backend `framework/sso-access/grants.json` (`docs/architecture/data-access.md`).

Then tell the person, in short lines:
- Which role Compass runs as, from the script's first line, and what it may write.
- If a browser window opened, log in with the Hiccup Google account and click Allow.
- In Compass: New connection, paste (the connection string is on the clipboard), Connect. The pasted string works until the login ends (about 8 hours); then type /hiccup-data:compass again. Do not save or share it: it holds a temporary key.
- If an alert says you hold no write grant on a scope: the line to ask for, as the alert names it.
- If an alert says Compass is not installed: download it from mongodb.com/products/compass, then type /hiccup-data:compass again.

---
description: Open MongoDB Compass logged in to Hiccup data (prod; add "dev" for the dev cluster, or a scope such as "orders" for that write role). Copies the connection string.
allowed-tools: Bash
---
Run `sh "${CLAUDE_PLUGIN_ROOT}/bin/hiccup-compass.sh" $ARGUMENTS` with the Bash tool, with a timeout of 330000 ms.

Then tell the person, in short lines:
- The role on the "Compass role:" line. AdministratorAccess and MongoWrite<Scope> can write; ClaudeFinance and ClaudeAnalytics read only. If a "Write roles you hold:" line lists more than one, say that `/hiccup-data:compass <scope>` (catalog, orders, supply, ops, storefront, finance, reports, hr, cms) picks one.
- If an alert says they have no write access for a scope, they ask Ronny for a grant of that MongoWrite set.
- If a browser window opened, log in with the Hiccup Google account and click Allow.
- In Compass: New connection, paste (the connection string is on the clipboard), Connect. The pasted string works until the login ends (about 8 hours); then type /hiccup-data:compass again. Do not save or share it: it holds a temporary key.
- If an alert says Compass is not installed: download it from mongodb.com/products/compass, then type /hiccup-data:compass again.

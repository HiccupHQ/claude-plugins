---
description: Open MongoDB Compass logged in to Hiccup data (prod; add "dev" for the dev cluster). Copies the connection string.
allowed-tools: Bash
---
Run `sh "${CLAUDE_PLUGIN_ROOT}/bin/hiccup-compass.sh" $ARGUMENTS` with the Bash tool, with a timeout of 330000 ms.

Then tell the person, in short lines:
- If a browser window opened, log in with the Hiccup Google account and click Allow.
- In Compass: New connection, paste (the connection string is on the clipboard), Connect. The pasted string works until the login ends (about 8 hours); then type /hiccup-data:compass again. Do not save or share it: it holds a temporary key.
- If an alert says Compass is not installed: download it from mongodb.com/products/compass, then type /hiccup-data:compass again.

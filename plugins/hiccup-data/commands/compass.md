---
description: Open MongoDB Compass logged in to Hiccup data (copies the connection string)
allowed-tools: Bash
---
Run `sh "${CLAUDE_PLUGIN_ROOT}/bin/hiccup-compass.sh"` with the Bash tool, with a timeout of 330000 ms.

Then tell the person, in short lines:
- If a browser window opened, log in with the Hiccup Google account and click Allow.
- In Compass: New connection, paste (the connection string is on the clipboard), Connect.
- If an alert says Compass is not installed: download it from mongodb.com/products/compass, then type /hiccup-data:compass again.

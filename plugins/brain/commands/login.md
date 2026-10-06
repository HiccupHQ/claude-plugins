---
description: Connect this machine to the company brain (once per machine)
allowed-tools: Bash
---
Connect this machine to the company brain.

Run this with the Bash tool, with a timeout of 330000 ms:

```
curl -fsSL 'https://brain-production-9a93.up.railway.app/login.sh?company=hiccup.com' | sh
```

It opens the browser and prints the same code the page shows. Tell the user, in one line, to check the code in the browser and click Connect.
- "Connected as ...": say they are connected, and that a session already open reconnects with /mcp, pick brain, Reconnect.
- "Request sent. Waiting for an admin": their address is not on a company domain, so an admin of the company approves them in the brain's admin page. Say so, and that the terminal connects by itself once approved.
- "Still waiting for an admin": tell them to run /brain:login again after the approval.
- "declined", "expired" or "Timed out": say which, in one line.

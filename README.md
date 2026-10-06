# Hiccup Claude Code plugins

## The company brain

Two commands, once per machine:

```
claude plugin marketplace add HiccupHQ/claude-plugins
claude plugin install brain@hiccup
```

Then, in Claude Code:

```
/brain:login
```

Your browser opens. Check the code and click **Connect this terminal**. A hiccup.com address
joins at once; any other address asks, and an admin approves it at
https://brain-production-9a93.up.railway.app/admin.

The plugin source lives in the brain repo (`plugin/`) and is published here with `plugin/publish.sh`.

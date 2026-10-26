---
name: aws-login
description: Renew the Hiccup AWS login (AWS SSO, Google account) for every Hiccup profile at once. Use it when an AWS call, a test, mongosh or a script says "Your session has expired", "Error when retrieving credentials from custom-process", "Token has expired and refresh failed", "The SSO session associated with this profile has expired", or the person says "login", "aws login", "renew aws". Claude runs the login itself; the person only approves in the browser.
---
# When to apply

- An AWS CLI call, a test, mongosh or a script fails because the AWS SSO login expired.
- The person asks to log in to AWS, or types `/hiccup-data:aws-login`.

# Setup

- One login covers every Hiccup account and role: IAM Identity Center, start URL `https://d-9c677602a8.awsapps.com/start`, signed in with the person's Hiccup Google account.
- `~/.aws/config` has `[sso-session hiccup]`. The profiles a person can use depend on the roles they are given:
  - `hiccup-claude-analytics`: read-only prod data (everyone with Hiccup data). hiccup-data writes it at session start.
  - `hiccup-claude-finance`: the same, and HR expenses (the finance team, ClaudeFinance). hx reads with it when the person has that role.
  - `hiccup-dev` and `hiccup-prod`: engineers (AdministratorAccess on dev 186923665223 and prod 310852620549).
  - `hiccup-prod-data`: prod Mongo read/write on every database for Compass (AdministratorAccess).
  - `hiccup-mongo-write-<scope>`: prod Mongo read/write on one domain for Compass (MongoWrite<Scope>, a grant with an end date). MongoProdAdmin is retired: `hiccup-mongo-admin` no longer works.
- `hiccup-dev` and `hiccup-prod` may read `hiccup-dev-sso` / `hiccup-prod-sso` through `credential_process = aws configure export-credentials …`. Keep that shape: the Kotlin AWS SDK in hiccup-backend has no SSO module and cannot read an SSO profile directly.
- Role credentials last 1 hour and renew by themselves while the SSO login is valid (about 8 hours).

# How

1. Find the AWS tool and the Hiccup profiles this person has:

```bash
AWS=$(command -v aws || echo "$HOME/aws-cli/aws")
grep -oE '^\[profile hiccup-[a-z-]+\]' ~/.aws/config | sed 's/\[profile //;s/\]//'
```

2. Check each of `hiccup-claude-analytics`, `hiccup-dev`, `hiccup-prod` that exists. If every one works, say so and stop:

```bash
"$AWS" --profile hiccup-dev sts get-caller-identity --query Account --output text
```

3. Start the login with the Bash tool, `run_in_background: true`:

```bash
"$AWS" sso login --sso-session hiccup 2>&1
```

4. Tell the person in one line: "Approve the AWS login in your browser." The command opens the browser by itself. If it did not open, give the person the URL and code from the background output file.
5. Wait for the background task to finish. You get a notification. Do not poll with sleep.
6. Run step 2 again. Report one line per profile: logged in, or the error.
   - "ForbiddenException: No access" means the person does not have that role. Say so; the person asks Ronny for it. Do not retry.
7. Retry the call that failed.

# If there is no `[sso-session hiccup]`

Add it, then go to step 3:

```bash
printf '\n[sso-session hiccup]\nsso_start_url = https://d-9c677602a8.awsapps.com/start\nsso_region = eu-west-2\nsso_registration_scopes = sso:account:access\n' >> ~/.aws/config
```

# Do not

- Do not export prod credentials into the session. Name the prod profile on each command.
- Do not print, copy or store the credentials.
- Do not change `hiccup-dev` or `hiccup-prod` from `credential_process` into direct SSO profiles.
- Do not add a `[default]` profile: a command without a profile must fail, never hit prod.

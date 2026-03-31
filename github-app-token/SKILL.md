---
name: github-app-token
description: Generate a GitHub installation access token from a GitHub App PEM key, App ID, and Installation ID, then authenticate the gh CLI with it.
---

# GitHub App Token Skill

Generate a short-lived GitHub installation access token from a GitHub App's credentials and use it to authenticate the `gh` CLI.

## Prerequisites

The following environment variables MUST be set before invoking this skill:

| Variable | Description |
|---|---|
| `GITHUB_APP_ID` | The numeric App ID from the GitHub App settings page |
| `GITHUB_APP_INSTALLATION_ID` | The numeric Installation ID for the target org/user |
| `GITHUB_APP_PEM_FILE` | Absolute path to the GitHub App's PEM private key file |

If any variable is missing, stop and tell the user which ones are required.

Requires `openssl`, `curl`, and `jq`.

## Generate a Token

Build a JWT signed with the App's private key, then exchange it for an installation access token:

```bash
# Base64url helper
b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

# Build JWT (valid 10 minutes)
NOW=$(date +%s)
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | jq -r -c .)
PAYLOAD=$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$NOW" "$((NOW + 600))" "$GITHUB_APP_ID" | jq -r -c .)
SIGNED=$(printf '%s' "$HEADER" | b64enc).$(printf '%s' "$PAYLOAD" | b64enc)
SIG=$(printf '%s' "$SIGNED" | openssl dgst -binary -sha256 -sign "$GITHUB_APP_PEM_FILE" | b64enc)
JWT="${SIGNED}.${SIG}"

# Exchange JWT for installation token
GH_TOKEN=$(curl -s -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens" \
  | jq -r '.token')

export GH_TOKEN
```

## Authenticate the gh CLI

With `GH_TOKEN` exported, the `gh` CLI uses it automatically for API operations:

```bash
gh api user
```

To persist into `gh auth` config:

```bash
echo "${GH_TOKEN}" | gh auth login --with-token
```

## Cleanup

The installation access token expires after 1 hour. To revoke it early:

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/installation/token"
```

## Security Notes

- Never log or echo the PEM key or installation token to stdout in production.
- The installation token is valid for 1 hour from generation.
- Store the PEM file with restrictive permissions (`chmod 600`) and never check it into git.

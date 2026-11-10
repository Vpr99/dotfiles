---
name: gws-accounts
description: Switches the Google Workspace CLI (gws) between Eric's work account (eric@northpole.security) and personal account (eric@skram.com), and repairs or adds an account login. Use when running any gws command for personal Gmail, Drive, Calendar, Docs or Sheets, when the user says "personal", "skram.com", "my other account" or "switch accounts" with gws, or when gws shows the wrong account, invalid_rapt, access_denied or an expired token.
---

# gws accounts

gws keeps one login per config directory. The env var `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` selects the directory.

| Account | Config dir | OAuth client project |
| --- | --- | --- |
| Work, eric@northpole.security (default) | `~/.config/gws` | `eric-playground-504618` (NPS org, Internal app) |
| Personal, eric@skram.com | `~/.config/gws-personal` | `nimble-net-502518-u3` (personal, External app) |

## Quick start

Work is the default. Use no env var:

```sh
gws drive files list --params '{"pageSize": 5}'
```

Personal: put the env var in front of **each** command. Do not `export` it. An exported var outlives the task and sends later work commands to the personal account.

```sh
GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-personal gws drive files list --params '{"pageSize": 5}'
```

If the user does not name an account, use work. If the task is plainly personal (family, personal email, a skram.com doc), use personal. If you cannot tell, ask.

## Check which account a command uses

```sh
gws gmail users getProfile --params '{"userId":"me"}' 2>/dev/null | jq -r .emailAddress
gws auth status 2>/dev/null | jq '{project_id, token_valid, token_error}'
```

Add the env var prefix to check personal. gws prints `Using keyring backend: …` on stderr, so send stderr to `/dev/null` before piping to `jq`.

## Log in or repair a login

Login prints a URL and waits for the browser to return to localhost. Run it in the background, read the URL from its output, and open it in the Chrome profile that matches the account. Plain `open <url>` goes to the work profile.

- Work: `open "<url>"`
- Personal: `open -na "Google Chrome" --args --profile-directory=Default "<url>"`

```sh
SCOPES=https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/presentations,https://www.googleapis.com/auth/tasks
gws auth login --scopes "$SCOPES"                                                    # work
GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-personal gws auth login --scopes "$SCOPES"   # personal
```

Rules:
- Always pass `--scopes`. Never use `-s/--services` or `--full`. Both add `cloud-platform`. NPS forces a re-sign-in on that scope every few hours, and the token then fails with `invalid_rapt`.
- `gws auth logout` deletes only that directory's `credentials.enc` and token cache. It keeps `client_secret.json`.
- Both directories share one encryption key in the macOS keychain (`gws-cli`). Do not delete that keychain item. It would break both logins.

## Errors

| Error | Cause | Fix |
| --- | --- | --- |
| `invalid_rapt` (work) | Token has `cloud-platform`, or the NPS session expired | Log in again with `--scopes` as above |
| `403 access_denied`, "has not completed the Google verification process" | The account is not allowed by that dir's OAuth app, usually the wrong account in the wrong dir | Log in with the account that matches the table. For personal, add eric@skram.com under Test users in `nimble-net-502518-u3` |
| Personal token dies after about 7 days | External apps in "Testing" mode expire refresh tokens after 7 days | In the console for `nimble-net-502518-u3`, set the app's publishing status to **In production**. Unverified is fine for one user; click through the warning on login |

## Add or rebuild an account

1. Make the dir: `mkdir -m 700 ~/.config/gws-<name>`.
2. Create a **Desktop app** OAuth client in a project that the account owns. Turn on the APIs first: `gcloud services enable drive.googleapis.com sheets.googleapis.com gmail.googleapis.com calendar-json.googleapis.com docs.googleapis.com slides.googleapis.com tasks.googleapis.com people.googleapis.com --project <id>`. This changes the cloud project, so ask Eric first.
3. Save the downloaded JSON as `~/.config/gws-<name>/client_secret.json` (`chmod 600`).
4. Log in with the env var prefix, then check the account as above.
5. Add a row to the table in this skill.

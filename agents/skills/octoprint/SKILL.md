---
name: octoprint
description: Controls Eric's OctoPrint server (http://octoprint, Prusa MINI+) on the LAN. It uploads G-code, lists files, and checks printer status, temperatures, and job progress. With explicit permission it starts, pauses, or cancels prints. Use when the user says octoprint, "send it to the printer", "upload the gcode", "is the print done", "how's the print going", printer status, or after the 3d-modeling skill produces G-code.
---

# OctoPrint

Everything goes through `scripts/octo.sh`. It reads the API key from 1Password
(`op://Private/octoprint/Agent API Key`, account `skram.1password.com`) inside the `op-work` tmux session
that the `one-password` skill requires, then relays the output. The key is never printed or written to disk.

```bash
O=~/.agents/skills/octoprint/scripts/octo.sh
$O status                    # connection, state, hotend/bed temps, current job + progress
$O files [N]                 # newest N .gcode files (default 15): path, bytes, date, est. seconds
$O info NAME                 # one file: size, date, estimated time, filament length
$O upload part.gcode         # upload only (never selects or prints); verifies remote size == local
$O upload part.gcode --select  # upload and load it, ready to print from the printer
$O snapshot out.jpg          # webcam still; exits 1 if the camera is down (it returns 503 when unplugged)
$O pause | resume
$O print NAME --confirm      # starts a print
$O cancel --confirm          # kills the running job
```

## Rules

- **Upload freely. Starting a print is a physical action.** Run `print --confirm` only when the user asked
  for a print in this conversation. Even then, check first with `status` that the printer is
  Operational and not already printing. Remind them to check the bed is clear, because you can't see it.
- **Never pass `--confirm` to `cancel` on your own judgment.** A failing print is the user's call. Report what you see.
- **Never overwrite the file that's printing.** Run `status` before you upload. If the name matches the
  current job, upload under a new name (`part_v2.gcode`); OctoPrint rejects the overwrite anyway.
- **OctoPrint wants plain `.gcode`.** If you get `.bgcode`, re-slice with `--no-binary-gcode`.
- **Times are in seconds.** Convert to hours and minutes when you talk to the user.

## When it fails

- **`op read` says "not signed in" or asks for a password.** The CLI isn't reaching the 1Password app.
  `octo.sh` sets `OP_BIOMETRIC_UNLOCK_ENABLED=true` (also set as a universal fish variable). Have the user
  unlock 1Password and check that Settings → Developer → "Integrate with 1Password CLI" is on.
  Never type their password and never use `op account add`.
- **HTTP 403:** wrong or revoked key. **HTTP 409** from `/api/printer`: the printer is disconnected.
  Tell the user to reconnect it from the OctoPrint UI or power-cycle the MINI.
- **`octoprint` doesn't resolve:** you're not on the home LAN.
- **The script hangs:** it waits up to 5 minutes for the tmux run, which covers a Touch ID prompt nobody answered.
  Check `tmux -S "${TMPDIR:-/tmp}/clawdbot-tmux-sockets/clawdbot-op.sock" capture-pane -p -t op-work:`.

For an endpoint the script doesn't cover, read https://docs.octoprint.org/en/master/api/. Add a
subcommand to `octo.sh` instead of writing one-off curl with the key inline.

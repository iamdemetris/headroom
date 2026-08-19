# Headroom

A macOS menu bar for Linux machines you already reach with SSH.

Add a VPS. See load, memory, disk, and top processes. Add as many hosts as you want. Headroom tells you whether the box still has room.

**Nothing is installed on the server. Nothing is exposed to the internet. Your hosts stay on your Mac.**

## Install

Download the notarized `Headroom-<version>.dmg` from [Releases](https://github.com/iamdemetris/headroom/releases), open it, and copy **Headroom** to `/Applications` or `~/Applications`.

Or build from source:

```bash
bash scripts/install.sh
```

Requires macOS 14+ on Apple Silicon.

## Self-update

The stable app checks GitHub Releases once a day. When a newer release is published you get a notification and an **Update** card inside the window. Clicking **Update** downloads the notarized DMG from the release and swaps the app in place (your saved hosts are untouched).

## Development

Iterate without touching the installed stable app:

```bash
bash scripts/dev.sh        # builds "Headroom Dev.app" and launches it
```

The dev build is fully separate (different name, bundle id, and saved-data folder) and shows a **DEV BUILD** badge so you always know which app you're looking at. When a change is ready to ship:

```bash
bash scripts/release.sh    # signs, notarizes, and publishes a GitHub release + DMG
```

The stable app will then show the update prompt. Bump the version in `scripts/version.txt` before releasing.

## Add a machine

1. Click **Headroom** in the menu bar.
2. Name the machine (`Production`).
3. Enter an SSH alias from `~/.ssh/config`, or `user@host`.
4. **Test connection**, then **Add and watch**.

Headroom only uses key-based SSH (`BatchMode`). It never asks for a password and never stores a key. Your host list lives in `~/Library/Application Support/Headroom/` and is not part of this repository.

The remote machine needs `python3` (default on Ubuntu). Headroom pipes a read-only `/proc` collector on stdin every 30 seconds. It does not write files on the server and does not run `ps`.

## Status

| Color | Meaning |
|---|---|
| Green **Headroom** | Comfortable |
| Amber **Busy** | Working hard, still okay |
| Red **Saturated** | At or over capacity |

## Security

See [SECURITY.md](SECURITY.md). Headroom opens outbound SSH only. Host names are passed as `ssh` arguments, never interpolated into a shell string.

## License

MIT

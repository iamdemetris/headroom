# Contributing

Headroom is a small Swift menu-bar app plus a read-only Linux collector.

## Build

```bash
bash scripts/build-app.sh
open dist/Headroom.app
```

Do not commit `dist/`, DMGs, Apple keys, or `hosts.json`. Never add a real SSH host, IP, or key to the repo. Examples use RFC documentation addresses only (`192.0.2.0/24`, `203.0.113.0/24`).

## Release (maintainers)

Notarization uses a **local** `notarytool` keychain profile. It is not stored in git.

```bash
bash scripts/release.sh
```

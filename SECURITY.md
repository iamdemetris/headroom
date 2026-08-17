# Security

Headroom watches Linux machines you already reach with SSH. It is designed so a public GitHub copy cannot become a backdoor.

## What Headroom does

- Opens an **outbound** SSH session using `/usr/bin/ssh` and your existing keys.
- Sends a read-only Python collector on stdin (`python3 -`). Nothing is installed on the server.
- Parses a size-capped JSON snapshot. Process names and resource numbers only.

## What Headroom never does

- Listen on a port
- Ask for or store SSH passwords or private keys
- Interpolate the host name into a shell string (host and port are `ssh` argv only)
- Accept host strings outside `[A-Za-z0-9._@-]`
- Phone home, collect telemetry, or open a metrics HTTP API

## Trust model

Anyone who can run commands as that SSH user can already see load and process names. Headroom does not increase that power. A hostile SSH host can return junk JSON; Headroom will reject it or show an error.

Use `BatchMode` hosts only. If a machine needs a password or an interactive prompt, Headroom will fail closed.

## Report a vulnerability

Open a private security advisory on the GitHub repository, or email the maintainer listed on the latest release. Please do not file a public issue for a working exploit.

#!/usr/bin/env python3
"""Read-only Linux snapshot. No network. No secrets. Printed as one JSON object."""
from __future__ import annotations

import json
import os
import socket
import subprocess
import time


def read_loadavg() -> tuple[float, float, float]:
    with open("/proc/loadavg", encoding="utf-8") as fh:
        parts = fh.readline().split()
    return float(parts[0]), float(parts[1]), float(parts[2])


def read_mem_mb() -> dict[str, int]:
    values: dict[str, int] = {}
    with open("/proc/meminfo", encoding="utf-8") as fh:
        for line in fh:
            key, raw, *_ = line.split()
            values[key.rstrip(":")] = int(raw)
    total = values["MemTotal"] // 1024
    available = values.get("MemAvailable", values.get("MemFree", 0)) // 1024
    used = max(0, total - available)
    swap_total = values.get("SwapTotal", 0) // 1024
    swap_free = values.get("SwapFree", 0) // 1024
    return {
        "mem_total_mb": total,
        "mem_used_mb": used,
        "mem_available_mb": available,
        "swap_total_mb": swap_total,
        "swap_used_mb": max(0, swap_total - swap_free),
    }


def read_stat() -> list[int]:
    with open("/proc/stat", encoding="utf-8") as fh:
        parts = fh.readline().split()
    return [int(x) for x in parts[1:]]


def cpu_sample(delay: float = 0.25) -> tuple[float, float, float]:
    a = read_stat()
    time.sleep(delay)
    b = read_stat()
    n = min(len(a), len(b))
    delta = [b[i] - a[i] for i in range(n)]
    total = sum(delta) or 1
    idle = delta[3] if n > 3 else 0
    iowait = delta[4] if n > 4 else 0
    steal = delta[7] if n > 7 else 0
    busy = max(0.0, 100.0 * (1.0 - (idle / total)))
    wait = 100.0 * iowait / total
    stolen = 100.0 * steal / total
    return round(busy, 1), round(wait, 1), round(stolen, 1)


def disk_root() -> dict[str, float | int]:
    st = os.statvfs("/")
    total = st.f_frsize * st.f_blocks
    free = st.f_frsize * st.f_bavail
    used = total - free
    pct = int(round(100.0 * used / total)) if total else 0
    return {
        "disk_total_gb": round(total / (1024**3), 1),
        "disk_used_gb": round(used / (1024**3), 1),
        "disk_used_pct": pct,
    }


def uptime_sec() -> int:
    with open("/proc/uptime", encoding="utf-8") as fh:
        return int(float(fh.readline().split()[0]))


def top_procs(limit: int = 5) -> list[dict[str, float | int | str]]:
    live: list[dict[str, float | int | str]] = []
    my_pid = os.getpid()
    try:
        out = subprocess.check_output(
            ["ps", "-eo", "pid,pcpu,pmem,comm", "--sort=-pcpu", "--no-headers"],
            text=True,
            timeout=2,
        )
        for line in out.splitlines():
            parts = line.split(None, 3)
            if len(parts) < 4:
                continue
            pid = int(parts[0])
            name = parts[3].strip()[:32]
            if pid == my_pid or name in {"ps", "python3", "python"}:
                continue
            live.append(
                {
                    "pid": pid,
                    "cpu": float(parts[1]),
                    "mem": float(parts[2]),
                    "name": name,
                }
            )
            if len(live) >= limit:
                break
    except (OSError, subprocess.SubprocessError, ValueError):
        return []
    return live


def main() -> None:
    load1, load5, load15 = read_loadavg()
    cpu_pct, iowait_pct, steal_pct = cpu_sample()
    payload = {
        "host": socket.gethostname(),
        "cpus": os.cpu_count() or 1,
        "load1": load1,
        "load5": load5,
        "load15": load15,
        "cpu_pct": cpu_pct,
        "iowait_pct": iowait_pct,
        "steal_pct": steal_pct,
        "uptime_sec": uptime_sec(),
        "top": top_procs(),
    }
    payload.update(read_mem_mb())
    payload.update(disk_root())
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()

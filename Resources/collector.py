#!/usr/bin/env python3
"""Read-only /proc snapshot. No sleep, no subprocess, no network."""
from __future__ import annotations

import json
import os
import socket


def loadavg() -> tuple[float, float, float]:
    with open("/proc/loadavg", encoding="utf-8") as fh:
        parts = fh.readline().split()
    return float(parts[0]), float(parts[1]), float(parts[2])


def mem_mb() -> dict[str, int]:
    values: dict[str, int] = {}
    with open("/proc/meminfo", encoding="utf-8") as fh:
        for line in fh:
            key, raw, *_ = line.split()
            values[key.rstrip(":")] = int(raw)
    total = values["MemTotal"] // 1024
    available = values.get("MemAvailable", values.get("MemFree", 0)) // 1024
    swap_total = values.get("SwapTotal", 0) // 1024
    swap_free = values.get("SwapFree", 0) // 1024
    return {
        "mem_total_mb": total,
        "mem_used_mb": max(0, total - available),
        "mem_available_mb": available,
        "swap_total_mb": swap_total,
        "swap_used_mb": max(0, swap_total - swap_free),
    }


def disk_root() -> dict[str, float | int]:
    st = os.statvfs("/")
    total = st.f_frsize * st.f_blocks
    free = st.f_frsize * st.f_bavail
    used = total - free
    return {
        "disk_total_gb": round(total / (1024**3), 1),
        "disk_used_gb": round(used / (1024**3), 1),
        "disk_used_pct": int(round(100.0 * used / total)) if total else 0,
    }


def uptime_sec() -> int:
    with open("/proc/uptime", encoding="utf-8") as fh:
        return int(float(fh.readline().split()[0]))


def main() -> None:
    load1, load5, load15 = loadavg()
    payload = {
        "host": socket.gethostname(),
        "cpus": os.cpu_count() or 1,
        "load1": load1,
        "load5": load5,
        "load15": load15,
        "uptime_sec": uptime_sec(),
    }
    payload.update(mem_mb())
    payload.update(disk_root())
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()

#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "psutil>=7.0.0",
# ]
# ///

from __future__ import annotations

import argparse
import json
import os
import shlex
import signal
import sys
import time
from dataclasses import asdict, dataclass
from typing import Iterable

import psutil


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit processes for zombies, hanging tasks, and likely stale duplicates.",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON.")
    parser.add_argument(
        "--min-age-seconds",
        type=int,
        default=900,
        help="Minimum age for stale-process heuristics. Default: 900.",
    )
    parser.add_argument(
        "--d-state-seconds",
        type=int,
        default=300,
        help="Minimum age for D-state processes to be flagged. Default: 300.",
    )
    parser.add_argument(
        "--cpu-idle-threshold",
        type=float,
        default=0.1,
        help="Max CPU percent for idle-process heuristics. Default: 0.1.",
    )
    parser.add_argument(
        "--kill-duplicates",
        action="store_true",
        help="Send SIGTERM to older duplicate dev-server processes.",
    )
    parser.add_argument(
        "--kill-zombies",
        action="store_true",
        help="Attempt to kill zombie parents when possible.",
    )
    parser.add_argument(
        "--grace-seconds",
        type=int,
        default=5,
        help="Wait time after kill attempts. Default: 5.",
    )
    return parser.parse_args()


@dataclass(frozen=True)
class ProcessRecord:
    pid: int
    ppid: int
    name: str
    status: str
    create_time: float
    cpu_percent: float
    cmdline: tuple[str, ...]
    cwd: str | None
    ports: tuple[int, ...]


@dataclass(frozen=True)
class Finding:
    kind: str
    pid: int
    action: str
    confidence: str
    reason: str
    command: str
    age_seconds: int
    ports: tuple[int, ...]
    cwd: str | None


def now_ts() -> float:
    return time.time()


def safe_cwd(process: psutil.Process) -> str | None:
    try:
        return process.cwd()
    except (psutil.AccessDenied, psutil.ZombieProcess, psutil.NoSuchProcess, FileNotFoundError):
        return None


def safe_cmdline(process: psutil.Process) -> tuple[str, ...]:
    try:
        return tuple(process.cmdline())
    except (psutil.AccessDenied, psutil.ZombieProcess, psutil.NoSuchProcess):
        return ()


def safe_ports(process: psutil.Process) -> tuple[int, ...]:
    try:
        connections = process.net_connections(kind="inet")
    except (psutil.AccessDenied, psutil.ZombieProcess, psutil.NoSuchProcess):
        return ()
    ports = sorted({conn.laddr.port for conn in connections if conn.status == psutil.CONN_LISTEN and conn.laddr})
    return tuple(ports)


def build_process_record(process: psutil.Process) -> ProcessRecord | None:
    try:
        with process.oneshot():
            return ProcessRecord(
                pid=process.pid,
                ppid=process.ppid(),
                name=process.name(),
                status=process.status(),
                create_time=process.create_time(),
                cpu_percent=process.cpu_percent(interval=None),
                cmdline=safe_cmdline(process),
                cwd=safe_cwd(process),
                ports=safe_ports(process),
            )
    except (psutil.NoSuchProcess, psutil.ZombieProcess, psutil.AccessDenied):
        return None


def collect_processes() -> list[ProcessRecord]:
    for process in psutil.process_iter():
        try:
            process.cpu_percent(interval=None)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    time.sleep(0.1)

    records: list[ProcessRecord] = []
    for process in psutil.process_iter():
        record = build_process_record(process)
        if record is not None:
            records.append(record)
    return records


def age_seconds(record: ProcessRecord, current_time: float) -> int:
    return max(0, int(current_time - record.create_time))


def render_command(record: ProcessRecord) -> str:
    if record.cmdline:
        return shlex.join(record.cmdline)
    return record.name


def normalized_signature(record: ProcessRecord) -> tuple[str, str | None, tuple[int, ...]]:
    command = render_command(record)
    return (command, record.cwd, record.ports)


def is_dev_server(record: ProcessRecord) -> bool:
    text = f"{record.name} {' '.join(record.cmdline)}".lower()
    markers = (
        "vite",
        "webpack",
        "next dev",
        "nuxt",
        "astro dev",
        "npm run dev",
        "pnpm dev",
        "yarn dev",
        "uvicorn",
        "gunicorn",
    )
    return any(marker in text for marker in markers)


def find_zombies(records: Iterable[ProcessRecord], current_time: float) -> list[Finding]:
    findings: list[Finding] = []
    for record in records:
        if record.status != psutil.STATUS_ZOMBIE:
            continue
        findings.append(
            Finding(
                kind="zombie",
                pid=record.pid,
                action="kill-parent",
                confidence="high",
                reason="Zombie process detected.",
                command=render_command(record),
                age_seconds=age_seconds(record, current_time),
                ports=record.ports,
                cwd=record.cwd,
            )
        )
    return findings


def find_d_state(records: Iterable[ProcessRecord], current_time: float, threshold: int) -> list[Finding]:
    findings: list[Finding] = []
    for record in records:
        if record.status != psutil.STATUS_DISK_SLEEP:
            continue
        record_age = age_seconds(record, current_time)
        if record_age < threshold:
            continue
        findings.append(
            Finding(
                kind="disk-sleep",
                pid=record.pid,
                action="review",
                confidence="high",
                reason=f"Process has been in D state for at least {threshold} seconds.",
                command=render_command(record),
                age_seconds=record_age,
                ports=record.ports,
                cwd=record.cwd,
            )
        )
    return findings


def group_duplicates(records: Iterable[ProcessRecord]) -> list[list[ProcessRecord]]:
    groups: dict[tuple[str, str | None, tuple[int, ...]], list[ProcessRecord]] = {}
    for record in records:
        if not is_dev_server(record):
            continue
        signature = normalized_signature(record)
        groups.setdefault(signature, []).append(record)
    return [group for group in groups.values() if len(group) > 1]


def sort_oldest_first(records: Iterable[ProcessRecord]) -> list[ProcessRecord]:
    return sorted(records, key=lambda item: item.create_time)


def find_duplicate_dev_servers(records: Iterable[ProcessRecord], current_time: float, min_age_seconds: int) -> list[Finding]:
    findings: list[Finding] = []
    for group in group_duplicates(records):
        ordered = sort_oldest_first(group)
        newest_pid = ordered[-1].pid
        for record in ordered[:-1]:
            record_age = age_seconds(record, current_time)
            if record_age < min_age_seconds:
                continue
            findings.append(
                Finding(
                    kind="duplicate-dev-server",
                    pid=record.pid,
                    action="kill-candidate",
                    confidence="high",
                    reason=f"Older duplicate dev-server process. Newer equivalent PID: {newest_pid}.",
                    command=render_command(record),
                    age_seconds=record_age,
                    ports=record.ports,
                    cwd=record.cwd,
                )
            )
    return findings


def find_idle_orphan_dev_servers(
    records: Iterable[ProcessRecord],
    current_time: float,
    min_age_seconds: int,
    cpu_idle_threshold: float,
) -> list[Finding]:
    findings: list[Finding] = []
    for record in records:
        if not is_dev_server(record):
            continue
        if record.ppid != 1:
            continue
        record_age = age_seconds(record, current_time)
        if record_age < min_age_seconds:
            continue
        if record.cpu_percent > cpu_idle_threshold:
            continue
        findings.append(
            Finding(
                kind="orphan-dev-server",
                pid=record.pid,
                action="review",
                confidence="medium",
                reason="Old orphaned dev-server process with low CPU activity.",
                command=render_command(record),
                age_seconds=record_age,
                ports=record.ports,
                cwd=record.cwd,
            )
        )
    return findings


def parent_pid_map(records: Iterable[ProcessRecord]) -> dict[int, int]:
    return {record.pid: record.ppid for record in records}


def kill_process(pid: int, sig: int) -> bool:
    try:
        os.kill(pid, sig)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return False


def kill_duplicate_candidates(findings: Iterable[Finding]) -> list[dict[str, object]]:
    actions: list[dict[str, object]] = []
    for finding in findings:
        if finding.kind != "duplicate-dev-server":
            continue
        actions.append({"pid": finding.pid, "signal": "SIGTERM", "sent": kill_process(finding.pid, signal.SIGTERM)})
    return actions


def zombie_parent_candidates(findings: Iterable[Finding], parent_map: dict[int, int]) -> list[int]:
    parents: list[int] = []
    for finding in findings:
        if finding.kind != "zombie":
            continue
        parent_pid = parent_map.get(finding.pid)
        if parent_pid and parent_pid > 1:
            parents.append(parent_pid)
    return sorted(set(parents))


def kill_zombie_parents(findings: Iterable[Finding], parent_map: dict[int, int]) -> list[dict[str, object]]:
    actions: list[dict[str, object]] = []
    for parent_pid in zombie_parent_candidates(findings, parent_map):
        actions.append({"pid": parent_pid, "signal": "SIGTERM", "sent": kill_process(parent_pid, signal.SIGTERM)})
    return actions


def collect_findings(
    records: list[ProcessRecord],
    current_time: float,
    min_age_seconds: int,
    d_state_seconds: int,
    cpu_idle_threshold: float,
) -> list[Finding]:
    findings = []
    findings.extend(find_zombies(records, current_time))
    findings.extend(find_d_state(records, current_time, d_state_seconds))
    findings.extend(find_duplicate_dev_servers(records, current_time, min_age_seconds))
    findings.extend(find_idle_orphan_dev_servers(records, current_time, min_age_seconds, cpu_idle_threshold))
    return sorted(findings, key=lambda item: (item.kind, -severity_rank(item.confidence), -item.age_seconds, item.pid))


def severity_rank(confidence: str) -> int:
    ranks = {"high": 3, "medium": 2, "low": 1}
    return ranks.get(confidence, 0)


def format_duration(seconds: int) -> str:
    minutes, sec = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    days, hours = divmod(hours, 24)
    if days:
        return f"{days}d{hours}h{minutes}m"
    if hours:
        return f"{hours}h{minutes}m{sec}s"
    if minutes:
        return f"{minutes}m{sec}s"
    return f"{sec}s"


def finding_to_dict(finding: Finding) -> dict[str, object]:
    data = asdict(finding)
    data["ports"] = list(finding.ports)
    return data


def render_text(findings: Iterable[Finding]) -> str:
    rows = list(findings)
    if not rows:
        return "No suspicious processes found."
    lines = []
    for finding in rows:
        ports = ",".join(str(port) for port in finding.ports) or "-"
        cwd = finding.cwd or "-"
        lines.append(
            " | ".join(
                [
                    f"[{finding.kind}]",
                    f"pid={finding.pid}",
                    f"action={finding.action}",
                    f"confidence={finding.confidence}",
                    f"age={format_duration(finding.age_seconds)}",
                    f"ports={ports}",
                    f"cwd={cwd}",
                    finding.reason,
                    finding.command,
                ]
            )
        )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    current_time = now_ts()
    records = collect_processes()
    findings = collect_findings(
        records=records,
        current_time=current_time,
        min_age_seconds=args.min_age_seconds,
        d_state_seconds=args.d_state_seconds,
        cpu_idle_threshold=args.cpu_idle_threshold,
    )

    actions: dict[str, list[dict[str, object]]] = {"kills": []}
    parent_map = parent_pid_map(records)

    if args.kill_duplicates:
        actions["kills"].extend(kill_duplicate_candidates(findings))
    if args.kill_zombies:
        actions["kills"].extend(kill_zombie_parents(findings, parent_map))

    if actions["kills"]:
        time.sleep(max(0, args.grace_seconds))

    if args.json:
        payload = {
            "findings": [finding_to_dict(item) for item in findings],
            "actions": actions,
        }
        print(json.dumps(payload, indent=2))
        return 0

    print(render_text(findings))
    if actions["kills"]:
        print("\nKill attempts:")
        for action in actions["kills"]:
            print(f"pid={action['pid']} signal={action['signal']} sent={action['sent']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

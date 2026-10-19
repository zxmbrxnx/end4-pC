#!/usr/bin/env python3
"""Bridge between the OpenCode V2 local API and Quickshell.

The bridge is read-only with respect to OpenCode. It discovers the shared
OpenCode service, polls its local HTTP API, and writes a normalized snapshot for
the desktop widgets. Actions such as replying to permissions are performed by
the QML service through the `opencode api` CLI.

It is designed to start with the desktop session, before OpenCode is running.
In that case it keeps retrying and reports `not_running` in the snapshot instead
of exiting or spamming errors.
"""

from __future__ import annotations

import argparse
import base64
import fcntl
import json
import os
import shutil
import signal
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_POLL_SECONDS = 2.0
HEARTBEAT_SECONDS = 10.0
STALE_GRACE_SECONDS = 300.0
HTTP_TIMEOUT_SECONDS = 3.0
SCHEMA_VERSION = 1

STOP_REQUESTED = False


def _now_ms() -> int:
    return int(time.time() * 1000)


def _xdg_state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))


def _default_state_path() -> Path:
    # Quickshell uses <XDG_STATE_HOME>/quickshell/user/... for per-user state.
    # The QML service passes --state-path explicitly; this default keeps manual
    # `--watch` runs in the same place.
    return _xdg_state_home() / "quickshell" / "user" / "opencode" / "state.json"


def _service_candidates() -> list[Path]:
    override = os.environ.get("OPENCODE_SERVICE_FILE")
    if override:
        return [Path(override)]
    return [
        _xdg_state_home() / "opencode" / "service.json",
        Path.home() / ".local" / "state" / "opencode" / "service.json",
        Path.home() / ".config" / "opencode" / "service.json",
    ]


def _pid_alive(pid: Any) -> bool:
    try:
        pid = int(pid)
    except (TypeError, ValueError):
        # A service file without a PID is unusual. Try to connect anyway.
        return True
    if pid <= 0:
        return True
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except (PermissionError, OSError):
        return True
    return True


def _read_service() -> dict[str, Any] | None:
    for path in _service_candidates():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            continue
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict):
            continue
        if not data.get("url") or not data.get("password"):
            continue
        if not _pid_alive(data.get("pid")):
            continue
        return data
    return None


class ApiError(Exception):
    """Base class for local OpenCode API failures."""


class Unauthorized(ApiError):
    """The service password is stale or the service was restarted."""


class NotFound(ApiError):
    """An endpoint is missing, usually because the API is not V2."""


class Unreachable(ApiError):
    """The service is registered but not accepting connections yet."""


class Incompatible(ApiError):
    """The service is running but does not expose the expected V2 API."""


_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _api_get(service: dict[str, Any], path: str, timeout: float = HTTP_TIMEOUT_SECONDS) -> Any:
    url = str(service["url"]).rstrip("/") + path
    password = str(service["password"])
    token = base64.b64encode(f"opencode:{password}".encode()).decode()
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Basic {token}",
            "Accept": "application/json",
            "User-Agent": "quickshell-opencode-bridge/1",
        },
    )
    try:
        with _OPENER.open(request, timeout=timeout) as response:
            body = response.read()
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            raise Unauthorized(f"HTTP {exc.code}") from exc
        if exc.code == 404:
            raise NotFound(f"HTTP 404: {path}") from exc
        if exc.code in (502, 503, 504):
            raise Unreachable(f"HTTP {exc.code}: {path}") from exc
        raise ApiError(f"HTTP {exc.code}: {path}") from exc
    except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as exc:
        raise Unreachable(str(exc)) from exc
    try:
        return json.loads(body)
    except json.JSONDecodeError as exc:
        raise ApiError(f"invalid JSON from {path}") from exc


def _unwrap(payload: Any) -> Any:
    if isinstance(payload, dict) and "data" in payload:
        return payload["data"]
    return payload


def _as_list(payload: Any) -> list[Any]:
    data = _unwrap(payload)
    return data if isinstance(data, list) else []


def _as_dict(payload: Any) -> dict[str, Any]:
    data = _unwrap(payload)
    return data if isinstance(data, dict) else {}


class Runtime:
    def __init__(self) -> None:
        self.last_snapshot: dict[str, Any] | None = None
        self.last_connected_at: float = 0.0
        self.permission_seen: dict[str, int] = {}


def _normalize_session(
    session: dict[str, Any],
    active: dict[str, Any],
    pending_permissions: list[dict[str, Any]],
) -> dict[str, Any]:
    session_id = str(session.get("id") or "")
    has_permission = any(p.get("sessionID") == session_id for p in pending_permissions)
    outcome = session.get("outcome")

    if has_permission:
        status = "waiting"
    elif session_id in active:
        status = "working"
    elif outcome == "failed":
        status = "error"
    else:
        status = "idle"

    model = session.get("model") or {}
    location = session.get("location") or {}
    tokens = session.get("tokens") or {}
    cache = tokens.get("cache") or {}
    timing = session.get("time") or {}

    return {
        "id": session_id,
        "title": session.get("title") or "Untitled session",
        "projectID": session.get("projectID"),
        "directory": location.get("directory") or "",
        "agent": session.get("agent") or "",
        "model": {
            "providerID": model.get("providerID") or "",
            "id": model.get("id") or "",
            "variant": model.get("variant") or "",
        },
        "status": status,
        "created": timing.get("created") or 0,
        "updated": timing.get("updated") or 0,
        "idle": timing.get("idle") or 0,
        "cost": session.get("cost") or 0,
        "tokens": {
            "input": tokens.get("input") or 0,
            "output": tokens.get("output") or 0,
            "reasoning": tokens.get("reasoning") or 0,
            "cache": {
                "read": cache.get("read") or 0,
                "write": cache.get("write") or 0,
            },
        },
        "parentID": session.get("parentID"),
        "outcome": outcome,
        "subagentCount": 0,
    }


def _fetch_connected(service: dict[str, Any], runtime: Runtime) -> dict[str, Any]:
    try:
        info = _as_dict(_api_get(service, "/api/info", timeout=2.0))
    except NotFound as exc:
        raise Incompatible("the service does not expose /api/info") from exc

    version = str(info.get("version") or service.get("version") or "")
    if version and not version.startswith("2."):
        raise Incompatible(f"unsupported OpenCode version: {version}")

    try:
        raw_sessions = _as_list(_api_get(service, "/api/session?limit=50&order=desc"))
    except NotFound as exc:
        raise Incompatible("the service does not expose /api/session") from exc

    try:
        active = _as_dict(_api_get(service, "/api/session/active"))
    except NotFound:
        active = {}

    try:
        raw_permissions = _as_list(_api_get(service, "/api/permission/request"))
    except NotFound:
        raw_permissions = []

    try:
        raw_forms = _as_list(_api_get(service, "/api/form"))
    except NotFound:
        raw_forms = []

    raw_permissions = [p for p in raw_permissions if isinstance(p, dict)]
    raw_forms = [f for f in raw_forms if isinstance(f, dict)]

    sessions = [
        _normalize_session(session, active, raw_permissions)
        for session in raw_sessions
        if isinstance(session, dict)
    ]

    counts: dict[str, int] = {}
    for session in sessions:
        parent_id = session.get("parentID")
        if parent_id:
            counts[parent_id] = counts.get(parent_id, 0) + 1
    for session in sessions:
        session["subagentCount"] = counts.get(session["id"], 0)

    rank = {"waiting": 0, "working": 1, "error": 2, "idle": 3}
    sessions.sort(key=lambda s: (rank.get(s["status"], 9), -(s["updated"] or 0)))

    session_by_id = {s["id"]: s for s in sessions}
    now = _now_ms()
    permissions: list[dict[str, Any]] = []
    for permission in raw_permissions:
        permission_id = str(permission.get("id") or "")
        session_id = str(permission.get("sessionID") or "")
        session = session_by_id.get(session_id, {})
        permissions.append(
            {
                "id": permission_id,
                "sessionID": session_id,
                "sessionTitle": session.get("title") or "",
                "directory": session.get("directory") or "",
                "action": permission.get("action") or "",
                "resources": permission.get("resources") or [],
                "save": permission.get("save") or [],
                "message": permission.get("message") or "",
                "metadata": permission.get("metadata") or {},
                "source": permission.get("source") or {},
                "waitingSince": runtime.permission_seen.get(permission_id, now),
            }
        )
    runtime.permission_seen = {
        p["id"]: runtime.permission_seen.get(p["id"], p["waitingSince"])
        for p in permissions
        if p.get("id")
    }

    forms: list[dict[str, Any]] = []
    for form in raw_forms:
        session_id = str(form.get("sessionID") or "")
        session = session_by_id.get(session_id, {})
        forms.append(
            {
                "id": str(form.get("id") or ""),
                "sessionID": session_id,
                "sessionTitle": session.get("title") or "",
                "directory": session.get("directory") or "",
                "title": form.get("title") or "",
                "fields": form.get("fields") or [],
                "metadata": form.get("metadata") or {},
            }
        )

    return {
        "schema": SCHEMA_VERSION,
        "state": "connected",
        "connected": True,
        "reason": "",
        "version": version,
        "pid": service.get("pid"),
        "url": service.get("url"),
        "checkedAt": now,
        "heartbeatAt": now,
        "retryInMs": 0,
        "stale": False,
        "sessions": sessions,
        "permissions": permissions,
        "forms": forms,
        "stats": None,
    }


def _disconnected(
    runtime: Runtime,
    state: str,
    reason: str,
    retry_ms: int,
) -> dict[str, Any]:
    keep_stale = (
        runtime.last_snapshot is not None
        and runtime.last_connected_at > 0
        and (time.monotonic() - runtime.last_connected_at) < STALE_GRACE_SECONDS
    )
    sessions = runtime.last_snapshot.get("sessions", []) if keep_stale and runtime.last_snapshot else []
    if keep_stale and state in ("not_running", "starting"):
        state = "reconnecting"
    now = _now_ms()

    return {
        "schema": SCHEMA_VERSION,
        "state": state,
        "connected": False,
        "reason": reason,
        "version": (runtime.last_snapshot or {}).get("version", ""),
        "pid": None,
        "url": "",
        "checkedAt": now,
        "heartbeatAt": now,
        "retryInMs": retry_ms,
        "stale": keep_stale,
        "sessions": sessions,
        "permissions": [],
        "forms": [],
        "stats": None,
    }


def _collect(runtime: Runtime, poll_seconds: float) -> dict[str, Any]:
    service = _read_service()

    if service is None:
        if shutil.which("opencode") is None:
            return _disconnected(runtime, "not_installed", "opencode is not installed", 60_000)
        return _disconnected(runtime, "not_running", "opencode is not running", int(poll_seconds * 1000))

    try:
        snapshot = _fetch_connected(service, runtime)
        runtime.last_snapshot = snapshot
        runtime.last_connected_at = time.monotonic()
        return snapshot
    except Unauthorized:
        return _disconnected(runtime, "starting", "opencode service authentication is not ready", 1_000)
    except Unreachable:
        return _disconnected(runtime, "starting", "opencode service is starting", 1_000)
    except Incompatible as exc:
        return _disconnected(runtime, "incompatible", str(exc), 60_000)
    except ApiError as exc:
        return _disconnected(runtime, "error", str(exc), int(poll_seconds * 1000))


def _mock_snapshot() -> dict[str, Any]:
    now = _now_ms()
    sessions = [
        {
            "id": "ses_mock_1",
            "title": "Refactor authentication",
            "projectID": "mock-project",
            "directory": "/tmp/opencode/project-a",
            "agent": "build",
            "model": {"providerID": "deepseek", "id": "deepseek-flash", "variant": "max"},
            "status": "waiting",
            "created": now - 600_000,
            "updated": now - 30_000,
            "idle": 0,
            "cost": 0.42,
            "tokens": {
                "input": 58_751,
                "output": 2_476,
                "reasoning": 3_034,
                "cache": {"read": 322_432, "write": 0},
            },
            "parentID": None,
            "outcome": None,
            "subagentCount": 1,
        },
        {
            "id": "ses_mock_1a",
            "title": "Search auth handlers",
            "projectID": "mock-project",
            "directory": "/tmp/opencode/project-a",
            "agent": "explore",
            "model": {"providerID": "deepseek", "id": "deepseek-flash", "variant": "max"},
            "status": "working",
            "created": now - 300_000,
            "updated": now - 5_000,
            "idle": 0,
            "cost": 0.05,
            "tokens": {"input": 0, "output": 0, "reasoning": 0, "cache": {"read": 0, "write": 0}},
            "parentID": "ses_mock_1",
            "outcome": None,
            "subagentCount": 0,
        },
        {
            "id": "ses_mock_2",
            "title": "Write tests for auth",
            "projectID": "mock-project",
            "directory": "/tmp/opencode/project-b",
            "agent": "build",
            "model": {"providerID": "anthropic", "id": "claude-sonnet-4-5", "variant": ""},
            "status": "working",
            "created": now - 900_000,
            "updated": now - 10_000,
            "idle": 0,
            "cost": 1.23,
            "tokens": {
                "input": 120_000,
                "output": 8_000,
                "reasoning": 1_000,
                "cache": {"read": 200_000, "write": 0},
            },
            "parentID": None,
            "outcome": None,
            "subagentCount": 0,
        },
        {
            "id": "ses_mock_3",
            "title": "Review dependency updates",
            "projectID": "mock-project",
            "directory": "/tmp/opencode/project-c",
            "agent": "plan",
            "model": {"providerID": "deepseek", "id": "deepseek-flash", "variant": "max"},
            "status": "idle",
            "created": now - 3_600_000,
            "updated": now - 1_200_000,
            "idle": now - 1_200_000,
            "cost": 0.08,
            "tokens": {"input": 0, "output": 0, "reasoning": 0, "cache": {"read": 0, "write": 0}},
            "parentID": None,
            "outcome": None,
            "subagentCount": 0,
        },
    ]
    permissions = [
        {
            "id": "per_mock_1",
            "sessionID": "ses_mock_1",
            "sessionTitle": "Refactor authentication",
            "directory": "/tmp/opencode/project-a",
            "action": "bash",
            "resources": ["npm test"],
            "save": ["npm test"],
            "message": "Run the test suite",
            "metadata": {},
            "source": {"type": "tool", "messageID": "msg_mock", "id": "tool_mock"},
            "waitingSince": now - 45_000,
        }
    ]
    return {
        "schema": SCHEMA_VERSION,
        "state": "connected",
        "connected": True,
        "reason": "",
        "version": "2.0.32-mock",
        "pid": os.getpid(),
        "url": "mock://opencode",
        "checkedAt": now,
        "heartbeatAt": now,
        "retryInMs": 0,
        "stale": False,
        "mock": True,
        "sessions": sessions,
        "permissions": permissions,
        "forms": [],
        "stats": None,
    }


def _fingerprint(snapshot: dict[str, Any]) -> str:
    stable = {
        key: value
        for key, value in snapshot.items()
        if key not in ("checkedAt", "heartbeatAt", "retryInMs")
    }
    return json.dumps(stable, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def _write_state(path: Path, snapshot: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        path.parent.chmod(0o700)
    except OSError:
        pass
    temporary = path.with_name(f"{path.name}.tmp.{os.getpid()}")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(snapshot, handle, ensure_ascii=False, separators=(",", ":"))
        handle.flush()
        os.fsync(handle.fileno())
    try:
        temporary.chmod(0o600)
    except OSError:
        pass
    os.replace(temporary, path)


def _acquire_lock(state_path: Path) -> Any:
    state_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock_path = state_path.parent / "bridge.lock"
    handle = lock_path.open("w", encoding="utf-8")
    try:
        os.chmod(lock_path, 0o600)
    except OSError:
        pass
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        return None
    handle.write(str(os.getpid()))
    handle.flush()
    return handle


def _handle_signal(_signum: int, _frame: Any) -> None:
    global STOP_REQUESTED
    STOP_REQUESTED = True


def _print_snapshot(snapshot: dict[str, Any]) -> None:
    json.dump(snapshot, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    sys.stdout.flush()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="print one snapshot and exit")
    parser.add_argument("--watch", action="store_true", help="continuously write the state file")
    parser.add_argument("--mock", action="store_true", help="use a fake connected snapshot")
    parser.add_argument("--state-path", type=Path, default=_default_state_path())
    parser.add_argument("--poll-interval", type=float, default=DEFAULT_POLL_SECONDS)
    parser.add_argument("--stdout", action="store_true", help="also emit each snapshot as one JSON line on stdout")
    parser.add_argument("--service-file", type=Path, help="override the OpenCode service registration file")
    parser.add_argument("--no-lock", action="store_true", help="do not use the single-instance lock")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    if args.service_file:
        os.environ["OPENCODE_SERVICE_FILE"] = str(args.service_file)
    args.poll_interval = max(0.5, args.poll_interval)

    if args.once:
        snapshot = _mock_snapshot() if args.mock else _collect(Runtime(), args.poll_interval)
        _print_snapshot(snapshot)
        return 0

    if not args.watch:
        parser.error("use --once or --watch")

    lock = None
    if not args.no_lock:
        lock = _acquire_lock(args.state_path)
        if lock is None:
            if args.verbose:
                print("another bridge instance is already running", file=sys.stderr)
            return 0

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    runtime = Runtime()
    last_fingerprint: str | None = None
    last_write = 0.0
    last_state = None

    while not STOP_REQUESTED:
        snapshot = _mock_snapshot() if args.mock else _collect(runtime, args.poll_interval)
        fingerprint = _fingerprint(snapshot)
        state = str(snapshot.get("state") or "")

        if args.verbose and state != last_state:
            print(f"{state}: {snapshot.get('reason', '')}", file=sys.stderr)
            last_state = state

        now = time.monotonic()
        if fingerprint != last_fingerprint or (now - last_write) >= HEARTBEAT_SECONDS:
            try:
                _write_state(args.state_path, snapshot)
            except OSError as exc:
                print(f"failed to write state: {exc}", file=sys.stderr)
            if args.stdout:
                print(json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")), flush=True)
            last_fingerprint = fingerprint
            last_write = now

        deadline = time.monotonic() + (snapshot.get("retryInMs", 0) or args.poll_interval * 1000) / 1000.0
        while not STOP_REQUESTED and time.monotonic() < deadline:
            time.sleep(min(0.2, max(0.0, deadline - time.monotonic())))

    if lock is not None:
        lock.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

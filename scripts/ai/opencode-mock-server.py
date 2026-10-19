#!/usr/bin/env python3
"""Small mock of the OpenCode V2 API for bridge and widget development.

This is only a development tool. It lets us test the bridge's connection
lifecycle without touching real OpenCode sessions:

    python3 scripts/ai/opencode-mock-server.py --service-file /tmp/opencode/mock-service.json &
    OPENCODE_SERVICE_FILE=/tmp/opencode/mock-service.json \
        python3 scripts/ai/opencode-bridge.py --watch

Stop and restart the mock server to simulate OpenCode starting late or crashing.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

MOCK_DIRECTORY = "/tmp/opencode/mock-project"


def _now_ms() -> int:
    return int(time.time() * 1000)


def _sessions() -> list[dict]:
    now = _now_ms()
    return [
        {
            "id": "ses_mock_1",
            "projectID": "mock-project",
            "agent": "build",
            "model": {"providerID": "deepseek", "id": "deepseek-flash", "variant": "max"},
            "cost": 0.42,
            "tokens": {
                "input": 58_751,
                "output": 2_476,
                "reasoning": 3_034,
                "cache": {"read": 322_432, "write": 0},
            },
            "time": {"created": now - 600_000, "updated": now - 30_000},
            "title": "Refactor authentication",
            "location": {"directory": MOCK_DIRECTORY},
        },
        {
            "id": "ses_mock_1a",
            "parentID": "ses_mock_1",
            "projectID": "mock-project",
            "agent": "explore",
            "model": {"providerID": "deepseek", "id": "deepseek-flash", "variant": "max"},
            "cost": 0.05,
            "tokens": {
                "input": 0,
                "output": 0,
                "reasoning": 0,
                "cache": {"read": 0, "write": 0},
            },
            "time": {"created": now - 300_000, "updated": now - 5_000},
            "title": "Search auth handlers",
            "location": {"directory": MOCK_DIRECTORY},
        },
        {
            "id": "ses_mock_2",
            "projectID": "mock-project",
            "agent": "build",
            "model": {"providerID": "anthropic", "id": "claude-sonnet-4-5"},
            "cost": 1.23,
            "tokens": {
                "input": 120_000,
                "output": 8_000,
                "reasoning": 1_000,
                "cache": {"read": 200_000, "write": 0},
            },
            "time": {"created": now - 900_000, "updated": now - 10_000},
            "title": "Write tests for auth",
            "location": {"directory": MOCK_DIRECTORY},
        },
        {
            "id": "ses_mock_3",
            "projectID": "mock-project",
            "agent": "plan",
            "model": {"providerID": "deepseek", "id": "deepseek-flash", "variant": "max"},
            "cost": 0.08,
            "tokens": {
                "input": 0,
                "output": 0,
                "reasoning": 0,
                "cache": {"read": 0, "write": 0},
            },
            "time": {"created": now - 3_600_000, "updated": now - 1_200_000},
            "title": "Review dependency updates",
            "location": {"directory": MOCK_DIRECTORY},
        },
    ]


def _permissions() -> list[dict]:
    return [
        {
            "id": "per_mock_1",
            "sessionID": "ses_mock_1",
            "action": "bash",
            "resources": ["npm test"],
            "save": ["npm test"],
            "message": "Run the test suite",
            "metadata": {},
            "source": {"type": "tool", "messageID": "msg_mock", "id": "tool_mock"},
        }
    ]


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenCodeMock/1.0"

    def log_message(self, _format: str, *_args: object) -> None:
        pass

    def _send(self, payload: object, status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - http.server API
        path = urlparse(self.path).path
        if path == "/api/info":
            self._send(
                {
                    "version": "2.0.32-mock",
                    "pid": os.getpid(),
                    "urls": [f"http://127.0.0.1:{self.server.server_address[1]}"],
                    "paths": {"tmp": "/tmp/opencode"},
                    "capabilities": {"persistentPty": True},
                }
            )
        elif path == "/api/session":
            self._send({"cursor": {"next": None, "previous": None}, "data": _sessions()})
        elif path == "/api/session/active":
            self._send(
                {
                    "data": {
                        "ses_mock_2": {"type": "running"},
                        "ses_mock_1a": {"type": "running"},
                    }
                }
            )
        elif path == "/api/permission/request":
            self._send(
                {
                    "location": {"directory": MOCK_DIRECTORY},
                    "data": _permissions(),
                }
            )
        elif path == "/api/form":
            self._send({"location": {"directory": MOCK_DIRECTORY}, "data": []})
        elif path == "/api/experimental/session/stats":
            self._send(
                {
                    "data": {
                        "range": {"from": 0, "to": _now_ms()},
                        "sessions": 4,
                        "subagents": 1,
                        "prompts": 12,
                        "steps": 42,
                        "tokens": {
                            "input": 178_751,
                            "output": 10_476,
                            "reasoning": 4_034,
                            "cache": {"read": 522_432, "write": 0},
                        },
                        "cost": 1.78,
                        "tools": {"mode": "summary", "totals": {"calls": 30, "succeeded": 29, "failed": 1, "unfinished": 0}},
                        "activeDays": 1,
                        "streak": 1,
                        "activity": [{"date": "2026-10-18", "steps": 42}],
                        "models": [],
                    }
                }
            )
        else:
            self._send({"_tag": "NotFoundError", "message": f"no mock route for {path}"}, 404)


def _write_service_file(path: Path, port: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "id": "mock",
                "password": "mock",
                "pid": os.getpid(),
                "url": f"http://127.0.0.1:{port}",
                "version": "2.0.32-mock",
            }
        ),
        encoding="utf-8",
    )
    try:
        path.chmod(0o600)
    except OSError:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=0, help="port to listen on (0 = random)")
    parser.add_argument(
        "--service-file",
        type=Path,
        default=Path("/tmp/opencode/opencode-mock-service.json"),
        help="service registration file to write",
    )
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.allow_reuse_address = True
    port = server.server_address[1]
    _write_service_file(args.service_file, port)

    print(f"mock OpenCode API listening on http://127.0.0.1:{port}", flush=True)
    print(f"service file: {args.service_file}", flush=True)

    stop_event = threading.Event()

    def stop(_signum: int, _frame: object) -> None:
        stop_event.set()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    try:
        while not stop_event.wait(0.25):
            pass
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
        try:
            args.service_file.unlink()
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

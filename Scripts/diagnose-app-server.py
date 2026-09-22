#!/usr/bin/env python3
"""Safely inspect the local Codex app-server rate-limit response shape.

This diagnostic intentionally prints only JSON keys, counts, window values,
and timestamp presence. It never prints raw responses or authentication data.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import select
import shutil
import subprocess
import sys
import time
from typing import Any


class DiagnosticFailure(RuntimeError):
    """Structured, safe failure emitted instead of raw process output."""

    def __init__(self, phase: str, status: str, message: str, code: int | None = None):
        super().__init__(message)
        self.phase = phase
        self.status = status
        self.message = redact(message)
        self.code = code


def redact(message: str) -> str:
    """Remove common credential, identifier, and header value patterns."""
    value = message.replace("\r", " ").replace("\n", " ")
    labeled = re.compile(
        r"(?i)\b(authorization|cookie|access[_-]?token|refresh[_-]?token|id[_-]?token|token|account[_-]?id|account\s+id|user[_-]?id|user\s+id)\s*[:=]\s*(\"[^\"]*\"|'[^']*'|[^\s,;]+)"
    )
    value = labeled.sub(r"\1=<redacted>", value)
    value = re.sub(r"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]+", "Bearer <redacted>", value)
    value = re.sub(r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b", "<redacted>", value)
    value = re.sub(r"(?i)\bauth\.json\b", "<redacted-file>", value)
    return value[:300] if value else "unknown error"


def failure_summary(failure: DiagnosticFailure) -> dict[str, Any]:
    summary: dict[str, Any] = {
        "phase": failure.phase,
        "status": failure.status,
        "errorMessage": failure.message,
    }
    if failure.code is not None:
        summary["errorCode"] = failure.code
    return summary


def find_codex(custom_path: str | None) -> str:
    candidates = [
        custom_path,
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
        os.path.expanduser("~/.local/bin/codex"),
        shutil.which("codex"),
    ]
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    raise RuntimeError("Codex CLI not found")


def send(process: subprocess.Popen[str], message: dict[str, Any]) -> None:
    assert process.stdin is not None
    try:
        process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
        process.stdin.flush()
    except BrokenPipeError as error:
        raise DiagnosticFailure("send", "brokenPipe", "communication pipe closed") from error


def read_response(process: subprocess.Popen[str], request_id: int, timeout: float = 10.0) -> dict[str, Any]:
    assert process.stdout is not None
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        remaining = max(0.0, deadline - time.monotonic())
        ready, _, _ = select.select([process.stdout], [], [], remaining)
        if not ready:
            break
        line = process.stdout.readline()
        if not line:
            raise DiagnosticFailure("read", "processExit", "app-server process exited")
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get("id") == request_id:
            return message
    raise DiagnosticFailure("read", "timeout", "request timed out")


def window_summary(window: Any) -> dict[str, Any] | None:
    if not isinstance(window, dict):
        return None
    return {
        "present": True,
        "usedPercent": window.get("usedPercent"),
        "windowDurationMins": window.get("windowDurationMins"),
        "resetsAtPresent": window.get("resetsAt") is not None,
    }


def bucket_summary(bucket: Any) -> dict[str, Any]:
    if not isinstance(bucket, dict):
        return {"validObject": False}
    return {
        "validObject": True,
        "primary": window_summary(bucket.get("primary")),
        "secondary": window_summary(bucket.get("secondary")),
    }


def safe_result_summary(result: Any) -> dict[str, Any]:
    if not isinstance(result, dict):
        return {"resultType": type(result).__name__}

    summary: dict[str, Any] = {"rootKeys": sorted(result.keys())}
    grouped = result.get("rateLimitsByLimitId")
    if isinstance(grouped, dict):
        summary["rateLimitsByLimitId"] = {
            "count": len(grouped),
            "buckets": {key: bucket_summary(value) for key, value in grouped.items()},
        }
    elif grouped is None:
        summary["rateLimitsByLimitId"] = None
    else:
        summary["rateLimitsByLimitId"] = {"type": type(grouped).__name__}

    if "rateLimits" in result:
        summary["rateLimits"] = bucket_summary(result["rateLimits"])
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-path", help="optional Codex executable path")
    args = parser.parse_args()

    try:
        codex = find_codex(args.codex_path or os.environ.get("CODEX_PATH"))
        process = subprocess.Popen(
            [codex, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        try:
            send(process, {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {
                        "name": "quota-bar-diagnostic",
                        "title": "Quota Bar Diagnostic",
                        "version": "0.1",
                    },
                    "capabilities": {"experimentalApi": True},
                },
            })
            initialize = read_response(process, 1)
            if "error" in initialize:
                error = initialize["error"]
                print(json.dumps(failure_summary(DiagnosticFailure(
                    "initialize", "rpcError", error.get("message", "initialize RPC failed"), error.get("code")
                )), indent=2, ensure_ascii=False))
                return 1

            send(process, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
            send(process, {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "account/rateLimits/read",
                "params": {"excludeResetCreditDetails": True},
            })
            response = read_response(process, 2)
            request_mode = "withParams"
            if response.get("error", {}).get("code") == -32600:
                # Current Codex CLI versions may require a unit/empty params
                # value even though older schemas accepted this option object.
                send(process, {
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "account/rateLimits/read",
                })
                response = read_response(process, 3)
                request_mode = "withoutParams"
            if "error" in response:
                error = response["error"]
                summary = failure_summary(DiagnosticFailure(
                    "account/rateLimits/read", "rpcError", error.get("message", "rate-limit RPC failed"), error.get("code")
                ))
                summary["requestMode"] = request_mode
                print(json.dumps(summary, indent=2, ensure_ascii=False))
                return 1

            summary = safe_result_summary(response.get("result"))
            summary["status"] = "success"
            summary["requestMode"] = request_mode
            print(json.dumps(summary, indent=2, ensure_ascii=False))
            return 0
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
    except DiagnosticFailure as error:
        print(json.dumps(failure_summary(error), indent=2, ensure_ascii=False))
        return 1
    except Exception as error:  # noqa: BLE001 - diagnostic must return a safe short error.
        print(json.dumps({"phase": "diagnostic", "status": "failure", "errorMessage": redact(str(error))}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

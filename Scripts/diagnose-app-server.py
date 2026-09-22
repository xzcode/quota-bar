#!/usr/bin/env python3
"""Safely inspect the local Codex app-server rate-limit response shape.

This diagnostic intentionally prints only JSON keys, counts, window values,
and timestamp presence. It never prints raw responses or authentication data.
"""

from __future__ import annotations

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import time
from typing import Any


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
    process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    process.stdin.flush()


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
            break
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get("id") == request_id:
            return message
    raise RuntimeError(f"timeout waiting for response id {request_id}")


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
                print(json.dumps({"phase": "initialize", "errorCode": initialize["error"].get("code")}, indent=2))
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
                print(json.dumps({"phase": "account/rateLimits/read", "errorCode": response["error"].get("code"), "requestMode": request_mode}, indent=2))
                return 1

            summary = safe_result_summary(response.get("result"))
            summary["requestMode"] = request_mode
            print(json.dumps(summary, indent=2, ensure_ascii=False))
            return 0
        finally:
            process.terminate()
            process.wait(timeout=3)
    except Exception as error:  # noqa: BLE001 - diagnostic must return a safe short error.
        print(f"diagnostic failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

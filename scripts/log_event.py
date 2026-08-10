#!/usr/bin/env python3
"""Appends a deployment/rollback event to a JSON log the dashboard reads."""
import argparse
import json
import os
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", required=True, choices=["success", "rollback", "failed"])
    parser.add_argument("--version", required=True)
    parser.add_argument("--log-path", required=True)
    parser.add_argument("--reason", default=None)
    args = parser.parse_args()

    os.makedirs(os.path.dirname(args.log_path), exist_ok=True)

    events = []
    if os.path.exists(args.log_path):
        with open(args.log_path) as f:
            try:
                events = json.load(f)
            except json.JSONDecodeError:
                events = []

    events.append(
        {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "version": args.version,
            "status": args.status,
            "reason": args.reason,
        }
    )

    with open(args.log_path, "w") as f:
        json.dump(events, f, indent=2)


if __name__ == "__main__":
    main()

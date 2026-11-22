#!/usr/bin/env python3
"""Small deterministic helpers for agent-relay shell scripts.

No third-party dependencies. Commands:
  now
  state-init FILE TASK_ID MODEL SESSION_ID
  state-get FILE DOT_PATH
  state-set FILE KEY=VALUE [KEY=VALUE ...]
  state-append-history FILE MODEL UNTIL AT
  frontmatter FILE KEY
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import re
import sys

TZ8 = _dt.timezone(_dt.timedelta(hours=8))


def fail(msg: str) -> None:
    print(f"[relay-lib] ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def now() -> str:
    return _dt.datetime.now(TZ8).isoformat(timespec="seconds")


def load_json(path: str) -> dict:
    if not os.path.isfile(path):
        fail(f"missing {path}")
    with open(path, encoding="utf-8") as fh:
        try:
            return json.load(fh)
        except json.JSONDecodeError as exc:
            fail(f"invalid JSON in {path}: {exc}")


def save_json(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def set_path(obj: dict, dotted: str, value) -> None:
    parts = dotted.split(".")
    cur = obj
    for part in parts[:-1]:
        if part not in cur or not isinstance(cur[part], dict):
            cur[part] = {}
        cur = cur[part]
    cur[parts[-1]] = value


def get_path(obj: dict, dotted: str):
    cur = obj
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def parse_value(raw: str):
    if raw == "null":
        return None
    if raw == "true":
        return True
    if raw == "false":
        return False
    if raw.startswith("[") or raw.startswith("{") or re.fullmatch(r"-?\d+", raw):
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
    return raw


def parse_frontmatter(path: str) -> dict:
    if not os.path.isfile(path):
        fail(f"missing {path}")
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    match = re.match(r"\A---\s*\n(.*?)\n---(?:\s*\n|\Z)", text, re.S)
    if not match:
        return {}
    result: dict = {}
    current_list_key: str | None = None
    for line in match.group(1).splitlines():
        list_item = re.match(r"^\s+-\s+(.*?)\s*$", line)
        top = re.match(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$", line)
        if list_item and current_list_key:
            result[current_list_key].append(parse_value(list_item.group(1)))
            continue
        current_list_key = None
        if not top:
            continue
        key, raw = top.group(1), top.group(2)
        if raw == "":
            result[key] = []
            current_list_key = key
        else:
            result[key] = parse_value(raw)
    return result


def main() -> None:
    if len(sys.argv) < 2:
        fail("usage: relay_lib.py <command> [args...]")
    cmd, args = sys.argv[1], sys.argv[2:]

    if cmd == "now":
        print(now())
        return

    if cmd == "state-init":
        if len(args) != 4:
            fail("state-init FILE TASK_ID MODEL SESSION_ID")
        path, task_id, model, session_id = args
        if os.path.isfile(path):
            print(f"[relay-lib] keep existing {path}")
            return
        template = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "..", "assets", "state.example.json"
        )
        with open(template, encoding="utf-8") as fh:
            data = json.load(fh)
        data["task_id"] = task_id
        data["updated_at"] = now()
        data["session"]["id"] = session_id
        data["session"]["model"] = model
        save_json(path, data)
        print(f"[relay-lib] created {path}")
        return

    if cmd == "state-get":
        if len(args) != 2:
            fail("state-get FILE DOT_PATH")
        value = get_path(load_json(args[0]), args[1])
        if value is None:
            print("")
        elif isinstance(value, (dict, list)):
            print(json.dumps(value, ensure_ascii=False))
        else:
            print(value)
        return

    if cmd == "state-set":
        if len(args) < 2:
            fail("state-set FILE KEY=VALUE [KEY=VALUE ...]")
        path = args[0]
        data = load_json(path)
        for item in args[1:]:
            if "=" not in item:
                fail(f"expected KEY=VALUE, got {item!r}")
            key, raw = item.split("=", 1)
            set_path(data, key, parse_value(raw))
        data["updated_at"] = now()
        save_json(path, data)
        return

    if cmd == "state-append-history":
        if len(args) != 4:
            fail("state-append-history FILE MODEL UNTIL AT")
        path, model, until, at = args
        data = load_json(path)
        session = data.setdefault("session", {})
        history = session.setdefault("model_history", [])
        history.append({"model": model, "until": until, "at": at})
        data["updated_at"] = now()
        save_json(path, data)
        return

    if cmd == "frontmatter":
        if len(args) != 2:
            fail("frontmatter FILE KEY")
        value = parse_frontmatter(args[0]).get(args[1])
        if value is None:
            print("")
        elif isinstance(value, list):
            print(json.dumps(value, ensure_ascii=False))
        else:
            print(value)
        return

    fail(f"unknown command: {cmd}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""CodeRig guard — refuses edits to blocked paths. Generated; do not edit.

Reads a PreToolUse hook payload on stdin, exits 2 to refuse the tool call.
Exit 0 allows it. Any unexpected failure also allows it: a broken guard must
never wedge a developer's session, because CI still enforces the same rules.

Regenerate with: coderig sync
"""
from __future__ import annotations

import fnmatch
import json
import sys
from pathlib import Path

BLOCKED = json.loads(r'''[
  ".github/workflows/**",
  "**/.env",
  "**/.env.*",
  "**/auth/**",
  "**/Auth/**",
  "**/security/**",
  "**/Security/**",
  "**/*Authentication*",
  "**/*Authorization*",
  "**/*.pem",
  "**/*.p12",
  "**/*.pfx",
  "**/id_rsa",
  "**/credentials"
]''')
REASONS = json.loads(r'''{
  ".github/workflows/**": "CI config defines the gates; agents must not edit it",
  "**/.env": "Contains secrets \u2014 never commit or overwrite",
  "**/.env.*": "Contains secrets \u2014 never commit or overwrite",
  "**/*.pem": "Private key material \u2014 never touch",
  "**/id_rsa": "Private key material \u2014 never touch"
}''')
# Role -> paths that role may write. The role is the one CodeRig connected this
# checkout with (.claude/settings.local.json). Enforced here rather than as
# Claude Code permission rules, where a broad deny always beats a narrow allow.
ROLE_SCOPE = json.loads(r'''{
  "developer": [
    "src/**",
    "tests/**",
    "docs/**"
  ],
  "tech-lead": [
    "src/**",
    "tests/**",
    "docs/**",
    "*.yaml",
    "*.yml",
    "*.toml",
    "*.json"
  ],
  "qa": [
    "tests/**",
    "docs/**"
  ],
  "ba": [
    "docs/**"
  ],
  "product-owner": [
    "docs/**"
  ]
}''')


def current_role(root: Path):
    try:
        local = json.loads((root / ".claude" / "settings.local.json").read_text(encoding="utf-8"))
        return local.get("_coderig_role")
    except (OSError, ValueError):
        return None


def in_scope(rel: str, patterns: list) -> bool:
    return any(fnmatch.fnmatch(rel, p) for p in patterns)


def target_paths(payload: dict) -> list[str]:
    """Pull candidate file paths out of a tool-call payload."""
    tool_input = payload.get("tool_input") or {}
    candidates = []
    for key in ("file_path", "path", "notebook_path"):
        value = tool_input.get(key)
        if isinstance(value, str):
            candidates.append(value)
    for edit in tool_input.get("edits", []) or []:
        if isinstance(edit, dict) and isinstance(edit.get("file_path"), str):
            candidates.append(edit["file_path"])
    return candidates


def normalise(raw: str, root: Path) -> str:
    path = Path(raw)
    try:
        return path.resolve().relative_to(root).as_posix()
    except (ValueError, OSError):
        # str.lstrip() strips CHARACTERS, not a prefix. Using it here turned
        # ".github/workflows/ci.yml" into "github/workflows/ci.yml" and
        # ".env" into "env", so every dotfile-rooted blocked pattern silently
        # stopped matching — including the CI and secrets rules.
        text = path.as_posix()
        while text.startswith("./"):
            text = text[2:]
        return text


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    # The repository is wherever this script lives (.coderig/ is one level down), not the
    # agent's current directory: an agent that has `cd`-ed into a subfolder would otherwise
    # make every blocked pattern fail to match.
    root = Path(__file__).resolve().parent.parent
    role = current_role(root)
    scope = ROLE_SCOPE.get(role) if role else None
    for raw in target_paths(payload):
        rel = normalise(raw, root)
        if scope is not None and scope != ["**"] and not in_scope(rel, scope):
            allowed = ", ".join(scope) if scope else "nothing (read-only role)"
            print(
                f"BLOCKED by CodeRig: {rel}\n"
                f"  role:    {role} may write only: {allowed}\n"
                f"  Stop and tell the developer; this role cannot make this change.",
                file=sys.stderr,
            )
            return 2
        for pattern in BLOCKED:
            if fnmatch.fnmatch(rel, pattern) or fnmatch.fnmatch(f"./{rel}", pattern):
                reason = REASONS.get(pattern, "blocked by the repository risk matrix")
                print(
                    f"BLOCKED by CodeRig: {rel}\n"
                    f"  matched: {pattern}\n"
                    f"  reason:  {reason}\n"
                    f"  This change needs a human. Stop and tell the developer "
                    f"rather than working around it.",
                    file=sys.stderr,
                )
                return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # never wedge the session; CI is the real gate
        sys.exit(0)

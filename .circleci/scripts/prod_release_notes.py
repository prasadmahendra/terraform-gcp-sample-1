#!/usr/bin/env python3
"""Build prod-deploy release notes for Slack from the git log.

Renders the commits applied since the last deployed SHA into a Slack mrkdwn
message (clickable commit + PR links, authors by git name — webapp-mono style)
and exports it as $SLACK_RELEASE_NOTES for the circleci/slack orb to post.

Posting is handled by the orb (see .circleci/config.yml), not here — this script
only produces the message, which keeps it easy to run/test locally:

    PREV_SHA=<sha> CURRENT_SHA=HEAD python3 .circleci/scripts/prod_release_notes.py

Inputs (env): PREV_SHA, CURRENT_SHA, PLAN_SUMMARY, SLACK_ONCALL,
CIRCLE_BUILD_URL, CIRCLE_REPOSITORY_URL.
Output: appends `export SLACK_RELEASE_NOTES=...` to $BASH_ENV (and prints the
rendered message to stdout). The exported value is JSON-escaped so it can be
dropped straight into the orb's `custom` payload as a quoted string.
"""
import json
import os
import re
import subprocess
import sys


def render() -> str:
    prev = os.environ.get("PREV_SHA", "").strip()
    cur = os.environ.get("CURRENT_SHA", "").strip() or "HEAD"
    build_url = os.environ.get("CIRCLE_BUILD_URL", "")
    plan_summary = os.environ.get("PLAN_SUMMARY", "").strip()
    oncall = os.environ.get("SLACK_ONCALL", "").strip()
    repo_url = os.environ.get("CIRCLE_REPOSITORY_URL", "")

    m = re.search(r"github\.com[:/]([^/]+)/([^/.]+)", repo_url)
    owner, repo = (m.group(1), m.group(2)) if m else ("spiffy-ai", "terraform")

    sep = "\x1f"
    fmt = sep.join(["%H", "%s", "%an"])
    try:
        args = ["git", "log", f"--format={fmt}"]
        args += [f"{prev}..{cur}"] if prev else ["-1", cur]
        out = subprocess.check_output(args, text=True)
    except subprocess.CalledProcessError as e:
        print(f"git log failed: {e}", file=sys.stderr)
        out = ""

    note_lines = []
    for line in out.splitlines():
        if not line.strip():
            continue
        h, subj, name = line.split(sep)
        url = f"https://github.com/{owner}/{repo}/commit/{h}"
        subj = re.sub(
            r"\(#(\d+)\)",
            rf"(<https://github.com/{owner}/{repo}/pull/\1|#\1>)",
            subj,
        )
        note_lines.append(f"• <{url}|{h[:7]}> {subj} — {name}")
    notes = "\n".join(note_lines) if note_lines else "_No new commits since last deploy_"

    cur_url = f"https://github.com/{owner}/{repo}/commit/{cur}"
    parts = [f":rocket: *Terraform prod deploy* — applied `<{cur_url}|{cur[:7]}>`"]
    if plan_summary:
        parts.append(f"*Plan:* {plan_summary}")
    parts.append(f"*Changes:*\n{notes}")
    if oncall:
        parts.append(f"*On-call:* {oncall}")
    if build_url:
        parts.append(f"<{build_url}|View build in CircleCI>")

    return "\n\n".join(parts)


def main() -> None:
    message = render()
    print(message)

    bash_env = os.environ.get("BASH_ENV")
    if not bash_env:
        return

    # JSON-escape so the value drops cleanly into the orb's `custom` JSON as a
    # quoted string; bash-escape single quotes so the export survives sourcing.
    escaped = json.dumps(message)[1:-1]
    bash_safe = escaped.replace("'", "'\\''")
    with open(bash_env, "a") as f:
        f.write(f"export SLACK_RELEASE_NOTES='{bash_safe}'\n")


if __name__ == "__main__":
    main()

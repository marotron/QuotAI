#!/usr/bin/env python3
"""PROTOTYPE — wipe / ignore. QuotAI throwaway Spending fetch PoC.

Question: Can we read live Cursor Models + Grok Bot meters from Cursor
Spending APIs using the hybrid auth path (state.vscdb → Bearer Connect)?

Run: python3 .scratch/quotai/poc/fetch_meters.py
"""

from __future__ import annotations

import json
import math
import sqlite3
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

VSCDB = Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
CONNECT_BASE = "https://api2.cursor.sh"
OAUTH_TOKEN = f"{CONNECT_BASE}/oauth/token"
CLIENT_ID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"
PERIOD_USAGE = f"{CONNECT_BASE}/aiserver.v1.DashboardService/GetCurrentPeriodUsage"
SAND_USAGE = f"{CONNECT_BASE}/aiserver.v1.DashboardService/GetSandUsageStatus"
SPENDING_URL = "https://cursor.com/dashboard/spending"
GREEN_LO, GREEN_HI = 0.90, 1.10


@dataclass
class Pace:
    ratio: float | None
    label: str
    early: bool
    days_to_exhaustion: float | None


def pace_ratio(percent_used: float, period_start: datetime, period_end: datetime, now: datetime) -> Pace:
    """Pure pace math (lift candidate for production)."""
    if percent_used >= 100:
        return Pace(None, "Exhausted", False, 0.0)
    total = (period_end - period_start).total_seconds()
    if total <= 0:
        return Pace(None, "Pace n/a", False, None)
    elapsed = max((now - period_start).total_seconds(), total / (24 * 30))  # ε ≈ 1h on ~30d
    t = min(max(elapsed / total, 1e-6), 1.0)
    r = (percent_used / 100.0) / t
    days_elapsed = max(elapsed / 86400.0, 1e-6)
    b = percent_used / days_elapsed
    d_ex = ((100.0 - percent_used) / b) if b > 0 else None
    early = bool(d_ex is not None and now.timestamp() + d_ex * 86400 < period_end.timestamp())
    pct = round(r * 100)
    if r < GREEN_LO:
        label = f"Under · {pct}% pace"
    elif r > GREEN_HI:
        label = f"Over · {pct}% pace"
    else:
        label = f"On pace · {pct}% pace"
    if early and d_ex is not None:
        label = f"{label} · ~{math.ceil(d_ex)}d left"
    return Pace(r, label, early, d_ex)


def read_tokens(db_path: Path) -> tuple[str | None, str | None, str | None]:
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        cur = con.cursor()

        def one(key: str) -> str | None:
            row = cur.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
            if not row or row[0] is None:
                return None
            val = row[0]
            if isinstance(val, bytes):
                val = val.decode("utf-8", errors="replace")
            return str(val).strip() or None

        return one("cursorAuth/accessToken"), one("cursorAuth/refreshToken"), one("cursorAuth/cachedEmail")
    finally:
        con.close()


def parse_ts(raw: Any) -> datetime | None:
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        ms = float(raw)
        if ms > 1e12:
            ms /= 1000.0
        return datetime.fromtimestamp(ms, tz=timezone.utc)
    s = str(raw).strip()
    if not s:
        return None
    if s.isdigit():
        return parse_ts(int(s))
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s).astimezone(timezone.utc)
    except ValueError:
        return None


def http_json(url: str, *, token: str | None = None, body: dict | None = None, cookie: str | None = None) -> tuple[int, Any]:
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
        headers["Connect-Protocol-Version"] = "1"
    if cookie:
        headers["Cookie"] = cookie
        headers["Origin"] = "https://cursor.com"
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if body is not None else "GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode() if e.fp else ""
        try:
            parsed = json.loads(raw) if raw else {"error": str(e)}
        except json.JSONDecodeError:
            parsed = {"error": raw or str(e)}
        return e.code, parsed


def refresh_access(refresh_token: str) -> tuple[str | None, dict]:
    status, payload = http_json(
        OAUTH_TOKEN,
        body={
            "grant_type": "refresh_token",
            "client_id": CLIENT_ID,
            "refresh_token": refresh_token,
        },
    )
    if status == 200 and isinstance(payload, dict) and payload.get("access_token"):
        return str(payload["access_token"]), payload
    return None, payload if isinstance(payload, dict) else {"status": status, "body": payload}


def connect_post(path_url: str, access: str) -> tuple[int, Any]:
    return http_json(path_url, token=access, body={})


def main() -> int:
    print("=== QuotAI PoC (THROWABLE) ===")
    print(f"Spending: {SPENDING_URL}")
    if not VSCDB.exists():
        print(f"FAIL: missing {VSCDB}", file=sys.stderr)
        return 1

    access, refresh, email = read_tokens(VSCDB)
    print(f"email: {email or '—'}")
    print(f"accessToken: {'yes' if access else 'no'}  refreshToken: {'yes' if refresh else 'no'}")
    if not access and not refresh:
        print("FAIL: no tokens in state.vscdb — sign into Cursor Desktop or paste path later", file=sys.stderr)
        return 1

    notes: list[str] = []
    if access:
        status, period = connect_post(PERIOD_USAGE, access)
        if status == 401 and refresh:
            notes.append("access 401 → oauth refresh")
            new_access, refresh_payload = refresh_access(refresh)
            if refresh_payload.get("shouldLogout"):
                print("FAIL: shouldLogout — re-login in Cursor", file=sys.stderr)
                print(json.dumps(refresh_payload, indent=2))
                return 1
            if not new_access:
                print("FAIL: refresh failed", file=sys.stderr)
                print(json.dumps(refresh_payload, indent=2))
                return 1
            access = new_access
            status, period = connect_post(PERIOD_USAGE, access)
    else:
        notes.append("no access — refresh first")
        access, refresh_payload = refresh_access(refresh)  # type: ignore[arg-type]
        if not access:
            print("FAIL: refresh failed", file=sys.stderr)
            print(json.dumps(refresh_payload, indent=2))
            return 1
        status, period = connect_post(PERIOD_USAGE, access)

    sand_status, sand = connect_post(SAND_USAGE, access)

    now = datetime.now(timezone.utc)
    out: dict[str, Any] = {
        "notes": notes,
        "spendingUrl": SPENDING_URL,
        "fetchedAt": now.isoformat(),
        "cursorModels": {"ok": False},
        "grokBot": {"ok": False},
    }

    if status == 200 and isinstance(period, dict):
        plan = period.get("planUsage") or {}
        auto = plan.get("autoPercentUsed")
        start = parse_ts(period.get("billingCycleStart"))
        end = parse_ts(period.get("billingCycleEnd"))
        days_left = None
        if end:
            days_left = max(0, math.ceil((end - now).total_seconds() / 86400))
        meter: dict[str, Any] = {
            "ok": auto is not None,
            "http": status,
            "percentUsed": auto,
            "daysLeft": days_left,
            "periodStart": start.isoformat() if start else None,
            "periodEnd": end.isoformat() if end else None,
        }
        if auto is not None and start and end:
            p = pace_ratio(float(auto), start, end, now)
            meter["pace"] = {
                "ratio": p.ratio,
                "label": p.label,
                "early": p.early,
                "daysToExhaustion": p.days_to_exhaustion,
            }
        out["cursorModels"] = meter
    else:
        out["cursorModels"] = {"ok": False, "http": status, "body": period}

    if sand_status == 200 and isinstance(sand, dict):
        usage = sand.get("usagePercent")
        reset = parse_ts(sand.get("nextResetTimestampUtc"))
        start = parse_ts(sand.get("currentPeriodStart"))
        pooled = sand.get("usesPooledEnterpriseAllowance")
        zero = sand.get("includedLimitZero") or not sand.get("hasNonZeroIncludedLimit", True)
        days_left = None
        if reset:
            days_left = max(0, math.ceil((reset - now).total_seconds() / 86400))
        eligible = usage is not None and not pooled and not zero
        meter = {
            "ok": bool(eligible),
            "http": sand_status,
            "percentUsed": usage,
            "daysLeft": days_left,
            "periodStart": start.isoformat() if start else None,
            "periodEnd": reset.isoformat() if reset else None,
            "pooled": pooled,
            "ineligible": not eligible,
        }
        if eligible and usage is not None and start and reset:
            p = pace_ratio(float(usage), start, reset, now)
            meter["pace"] = {
                "ratio": p.ratio,
                "label": p.label,
                "early": p.early,
                "daysToExhaustion": p.days_to_exhaustion,
            }
        elif eligible and usage is not None:
            meter["pace"] = {"ratio": None, "label": "Pace n/a", "early": False}
        out["grokBot"] = meter
    else:
        out["grokBot"] = {"ok": False, "http": sand_status, "body": sand}

    print(json.dumps(out, indent=2))
    ok = bool(out["cursorModels"].get("ok")) and bool(out["grokBot"].get("ok"))
    # Success for PoC: Cursor Models required; Grok may be ineligible → still print, exit 0 if Cursor ok
    if out["cursorModels"].get("ok"):
        if not out["grokBot"].get("ok"):
            print("WARN: Grok Bot unavailable/ineligible (expected error-row behavior)", file=sys.stderr)
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

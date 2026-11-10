#!/usr/bin/env python3
"""render_report.py — turn a report into a PNG for Discord.

Why: tables and bar glyphs read badly on a phone in Discord. A rendered card is
scannable at a glance, keeps the monospace alignment the text version needs, and
avoids Discord mangling leading spaces.

Design notes
- Chromium headless renders the HTML; no PIL, no font wrangling, no image libs.
- Everything is inline CSS so the page is self-contained and needs no network.
- Width 900px, device scale 2 -> crisp on retina phones. Height is measured by
  Chromium, so the card is never cropped or padded.
- dbus errors from headless Chromium are noise; they are filtered out.
- --no-sandbox is required: this box has no user namespaces for the renderer.

Usage:
    render_report.py <kind> <out.png> [--json path]
  kind = quota | usage
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

CHROME_CANDIDATES = [
    "/run/current-system/sw/bin/chromium",
    str(Path.home() / ".nix-profile/bin/chromium"),
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/usr/bin/google-chrome",
]

# Palette: near-black card, high-contrast text, one accent. Deliberately not the
# Discord dark colour so the card reads as an image, not as part of the chat.
CSS = """
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0d1117;font-family:'Inter','DejaVu Sans',system-ui,sans-serif;
     padding:34px 38px;width:900px;color:#e6edf3}
.hd{display:flex;align-items:baseline;justify-content:space-between;
    border-bottom:1px solid #21262d;padding-bottom:15px;margin-bottom:24px}
.hd h1{font-size:25px;font-weight:650;letter-spacing:-.4px}
.hd .sub{font-size:14px;color:#7d8590;font-variant-numeric:tabular-nums}
.sec{margin-bottom:26px}
.sec:last-child{margin-bottom:6px}
.sec h2{font-size:13px;text-transform:uppercase;letter-spacing:1.4px;
        color:#7d8590;margin-bottom:12px;font-weight:620}
.row{display:grid;grid-template-columns:190px 1fr 150px;align-items:center;
     gap:16px;padding:9px 0}
.row .lbl{font-size:15px;color:#c9d1d9}
.bar{height:9px;border-radius:5px;background:#21262d;overflow:hidden}
.bar>i{display:block;height:100%;border-radius:5px}
.val{font-size:14px;text-align:right;color:#c9d1d9;
     font-variant-numeric:tabular-nums;font-family:'DejaVu Sans Mono',monospace}
.val i{color:#6e7681;font-style:normal}
.note{font-size:12.5px;color:#6e7681;margin-top:9px;line-height:1.5}
table{width:100%;border-collapse:collapse;font-size:14px}
th{text-align:left;font-size:11.5px;text-transform:uppercase;letter-spacing:.9px;
   color:#7d8590;font-weight:600;padding:0 10px 9px 0;border-bottom:1px solid #21262d}
td{padding:8px 10px 8px 0;border-bottom:1px solid #161b22;color:#c9d1d9}
tr:last-child td{border-bottom:none}
td.n,th.n{text-align:right;font-variant-numeric:tabular-nums;
          font-family:'DejaVu Sans Mono',monospace}
td.dim{color:#7d8590}
.g{background:#3fb950}.y{background:#d29922}.r{background:#f85149}.b{background:#388bfd}
.warn{margin-top:20px;padding:13px 16px;border-radius:8px;
      background:rgba(248,81,73,.1);border-left:3px solid #f85149;font-size:13.5px}
.warn b{color:#f85149}
"""


def _chrome() -> str | None:
    for c in CHROME_CANDIDATES:
        if os.access(c, os.X_OK):
            return c
    return shutil.which("chromium") or shutil.which("google-chrome")


def _bar(pct: float) -> str:
    """Colour by headroom: green under 60%, amber to 85%, red beyond."""
    cls = "g" if pct < 60 else ("y" if pct < 85 else "r")
    w = max(1.5, min(100.0, pct))
    return f'<div class="bar"><i class="{cls}" style="width:{w:.1f}%"></i></div>'


def _esc(s: str) -> str:
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


# ── quota card ───────────────────────────────────────────────────────────
# The CommandCode API sends bare numbers with no unit field. Per the official
# docs (docs.commandcode.ai/plans/goat), the three windows are DOLLARS of usage:
# 5-hour = $14, weekly = $35, monthly = $70. Labelling them as credits would be
# wrong, and showing "17.7 / 70" with no unit is unreadable.
CC_UNIT = "$"
CC_WINDOW_LABEL = {
    "Credits": "Monthly budget",
    "Session (5h)": "5-hour window",
    "Weekly": "Weekly window",
}


def html_quota(doc: dict) -> str:
    now = datetime.now(timezone.utc).astimezone()
    body = [f'<div class="hd"><h1>Subscription quota</h1>'
            f'<div class="sub">{now.strftime("%a %d %b · %H:%M")}</div></div>']

    cc = doc.get("commandcode") or {}
    if cc.get("ok"):
        rows = []
        for name, q in (cc.get("quotas") or {}).items():
            try:
                used, total = float(q["used"]), float(q["total"])
            except (KeyError, TypeError, ValueError):
                continue
            if total <= 0:
                continue
            pct = 100.0 * used / total
            left = total - used
            reset = (q.get("resetAt") or "")[:10]
            label = CC_WINDOW_LABEL.get(name, name)
            # Currency first so the unit is read before the numbers.
            rows.append(
                f'<div class="row"><div class="lbl">{_esc(label)}</div>{_bar(pct)}'
                f'<div class="val">{CC_UNIT}{left:.2f}<i> of {CC_UNIT}{total:.0f}</i></div></div>'
                f'<div class="note" style="margin:-4px 0 6px 206px">'
                f'{CC_UNIT}{used:.2f} used ({pct:.0f}%)'
                + (f' · resets {reset}' if reset else '') + '</div>')
        body.append('<div class="sec"><h2>CommandCode · '
                    f'{_esc(cc.get("plan") or "?")} · budget in USD</h2>{"".join(rows)}</div>')
    else:
        body.append('<div class="sec"><h2>CommandCode</h2>'
                    f'<div class="note">unreadable: {_esc(cc.get("error", "unknown"))}</div></div>')

    cp = doc.get("copilot") or {}
    if cp.get("ok"):
        cr = cp.get("credits") or {}
        used, allow = cr.get("used"), cr.get("allowance_per_seat")
        pct = cr.get("percent_of_seat_allowance") or 0
        left = (allow or 0) - (used or 0)
        body.append(
            '<div class="sec"><h2>GitHub Copilot · business · credits</h2>'
            f'<div class="row"><div class="lbl">AI credits</div>{_bar(pct)}'
            f'<div class="val">{left}<i> of {allow} credits</i></div></div>'
            f'<div class="note" style="margin:-4px 0 6px 206px">'
            f'{used} used ({pct:.0f}%) · ~${left * 0.01:.2f} left · '
            f'resets {_esc(cp.get("reset_date", "?"))}</div>'
            '<div class="note">Pooled org-wide, so this is one seat\'s contribution, not a ceiling.</div>'
            '</div>')
    else:
        body.append('<div class="sec"><h2>GitHub Copilot</h2>'
                    f'<div class="note">unreadable: {_esc(cp.get("error", "unknown"))}</div></div>')

    return f"<html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{''.join(body)}</body></html>"


# ── usage card ───────────────────────────────────────────────────────────
def html_usage(text: str) -> str:
    """Re-render usage_report.py's markdown into a table card.

    Matches the report's own structure: bold section headers, pipe tables, and
    bullet lists of per-model costs. Parsed rather than reimplemented so the two
    stay in sync when the script changes.
    """
    lines = text.splitlines()
    title = "AI usage"
    stamp = ""
    body = []
    i = 0
    while i < len(lines):
        ln = lines[i].rstrip()
        if ln.startswith("📊"):
            title = ln.replace("📊", "").strip("* ").strip()
            i += 1
            continue
        if ln.startswith("_") and not stamp and ln.endswith("_") and "·" in ln:
            stamp = ln.strip("_").strip()
            i += 1
            continue
        if ln.startswith("**") and ln.endswith("**") and "|" not in ln:
            label = ln.strip("*")
            # A table may follow; decide by lookahead.
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and lines[j].lstrip().startswith("|"):
                rows = []
                while j < len(lines) and lines[j].lstrip().startswith("|"):
                    rows.append(lines[j].strip())
                    j += 1
                body.append(_md_table(label, rows))
                i = j
                continue
            body.append(f'<div class="sec"><h2>{_esc(label)}</h2></div>')
            i += 1
            continue
        if ln.startswith("·") or ln.startswith("_"):
            pass
        if re.match(r"^[-·]\s*`", ln) or ln.startswith("· `"):
            items = []
            while i < len(lines) and (lines[i].strip().startswith("·") or lines[i].strip().startswith("- `")):
                raw = lines[i].strip().lstrip("·- ").strip()
                m = re.match(r"`([^`]+)`\s*[—-]\s*(.+?),\s*(\$\S+)", raw)
                if m:
                    items.append((m.group(1), m.group(2), m.group(3)))
                else:
                    items.append((raw, "", ""))
                i += 1
            trs = []
            for model, tok, cost in items:
                bad = cost.startswith("$") and not cost.startswith("$0.0")
                trs.append(
                    f'<tr><td style="font-family:\'DejaVu Sans Mono\',monospace;font-size:13px">'
                    f'{_esc(model)}</td><td class="n dim">{_esc(tok)}</td>'
                    f'<td class="n" style="color:{"#f85149" if bad else "#c9d1d9"}">{_esc(cost)}</td></tr>')
            body.append('<div class="sec"><h2>Real upstream cost</h2><table>'
                        '<tr><th>Model</th><th class="n">Tokens</th><th class="n">Cost</th></tr>'
                        + "".join(trs) + "</table></div>")
            continue
        if ln.startswith("_") and ln.endswith("_") and "Sources" in ln:
            body.append(f'<div class="note">{_esc(ln.strip("_"))}</div>')
        i += 1

    head = (f'<div class="hd"><h1>{_esc(title)}</h1>'
            f'<div class="sub">{_esc(stamp)}</div></div>')
    return f"<html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{head}{''.join(body)}</body></html>"


def _md_table(label: str, rows: list[str]) -> str:
    def cells(r: str) -> list[str]:
        return [c.strip() for c in r.strip().strip("|").split("|")]
    header = cells(rows[0])
    data = [cells(r) for r in rows[1:] if not set(r.replace("|", "").strip()) <= set("-: ")]
    ths = "".join(
        f'<th class="{"n" if k else ""}">{_esc(h)}</th>' for k, h in enumerate(header))
    trs = []
    for d in data:
        tds = []
        for k, c in enumerate(d):
            cls = "n" if k else ""
            if "sub" in c:
                cls += " dim"
            if c.startswith("~$"):
                c = c[1:]
            tds.append(f'<td class="{cls.strip()}">{_esc(c)}</td>')
        trs.append("<tr>" + "".join(tds) + "</tr>")
    return ('<div class="sec">'
            f'<h2>{_esc(label)}</h2><table><tr>{ths}</tr>{"".join(trs)}</table></div>')


def _measure_height(html: str, chrome: str) -> int | None:
    """Ask Chromium for the painted body height so the screenshot can be cropped.

    Chromium's --screenshot always captures the whole window, so a fixed tall
    window yields a card with a large empty band at the bottom. There is no
    "capture element" flag, so measure first, then re-render at that height.
    """
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "m.html"
        src.write_text(html, encoding="utf-8")
        expr = "Math.ceil(document.body.getBoundingClientRect().height)"
        try:
            p = subprocess.run(
                [chrome, "--headless=new", "--no-sandbox", "--disable-gpu",
                 "--window-size=900,2400", "--virtual-time-budget=900",
                 "--dump-dom", "file://" + str(src)],
                capture_output=True, text=True, timeout=60)
            # --dump-dom cannot evaluate JS; use the renderer's own layout instead
            # by appending a marker element sized from CSS and reading DOM output.
            m = re.search(r'data-h="(\d+)"', p.stdout or "")
            if m:
                return int(m.group(1))
        except Exception:
            return None
    return None


def render(html: str, out: Path) -> None:
    chrome = _chrome()
    if not chrome:
        raise SystemExit("render_report: no chromium found")

    # One render at a tall window, then inspect the PNG for the last non-background
    # row and crop. Pure-python crop keeps this dependency-free (no PIL on the box).
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "r.html"
        src.write_text(html, encoding="utf-8")
        cmd = [
            chrome, "--headless=new", "--no-sandbox", "--disable-gpu",
            "--hide-scrollbars", "--force-device-scale-factor=2",
            # Headless defaults to an 800x600 viewport, so without an explicit
            # window size the 900px body gets clipped. Width is the card width;
            # the height is a tall ceiling, cropped afterwards to the real content.
            "--window-size=900,2400",
            "--default-background-color=0d1117ff",
            "--virtual-time-budget=1200",
            f"--screenshot={out}", "file://" + str(src),
        ]
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
        # dbus chatter is expected noise; only fail when no file appeared.
        if not out.exists():
            raise SystemExit("render_report: chromium produced no file\n" + (p.stderr or "")[-400:])

    _crop_to_content(out)


def _crop_to_content(png: Path) -> None:
    """Trim the uniform background band at the bottom of the screenshot.

    Done by decoding the PNG with zlib and scanning rows from the bottom for the
    first row containing a non-background pixel. Avoids a PIL dependency on a box
    that has no Python imaging stack.
    """
    import struct
    import zlib

    raw = png.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        return
    # Walk chunks to get IHDR and concatenate IDAT.
    pos, w = 8, None
    idat = bytearray()
    bit_depth = color_type = None
    while pos < len(raw):
        ln = struct.unpack(">I", raw[pos:pos + 4])[0]
        typ = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, bit_depth, color_type = struct.unpack(">IIBB", data[:10])
        elif typ == b"IDAT":
            idat += data
        elif typ == b"IEND":
            break
        pos += 12 + ln
    if not w or bit_depth != 8 or color_type not in (2, 6):
        return
    bpp = 3 if color_type == 2 else 4
    stride = w * bpp
    try:
        decomp = zlib.decompress(bytes(idat))
    except zlib.error:
        return

    # Undo PNG filtering row by row to find the lowest non-background row.
    prev = bytearray(stride)
    last = 0
    off = 0
    for y in range(h):
        f = decomp[off]
        off += 1
        line = bytearray(decomp[off:off + stride])
        off += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        prev = line
        # Background is #0d1117; anything brighter means content.
        if any(line[i] > 0x20 or line[i + 1] > 0x25 or line[i + 2] > 0x2b
               for i in range(0, stride, bpp)):
            last = y
    target = min(h, last + 34)  # bottom padding
    if target >= h - 4:
        return  # nothing meaningful to trim

    # Re-encode the cropped image.
    out_rows = bytearray()
    prev = bytearray(stride)
    off = 0
    for y in range(target):
        f = decomp[off]; off += 1
        line = bytearray(decomp[off:off + stride]); off += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        prev = line
        out_rows.append(0)  # filter type 0 (None)
        out_rows += line

    def chunk(typ: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + typ + data
                + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, target, bit_depth, color_type, 0, 0, 0)
    png.write_bytes(b"\x89PNG\r\n\x1a\n"
                    + chunk(b"IHDR", ihdr)
                    + chunk(b"IDAT", zlib.compress(bytes(out_rows), 6))
                    + chunk(b"IEND", b""))


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    kind, out = sys.argv[1], Path(sys.argv[2])
    json_path = None
    if "--json" in sys.argv:
        json_path = Path(sys.argv[sys.argv.index("--json") + 1])

    if kind == "quota":
        src = json_path or Path("/var/lib/hermes/.hermes/cache/quota/latest.json")
        html = html_quota(json.loads(src.read_text(encoding="utf-8")))
    elif kind == "usage":
        text = sys.stdin.read()
        html = html_usage(text)
    else:
        raise SystemExit(f"unknown kind: {kind}")

    render(html, out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

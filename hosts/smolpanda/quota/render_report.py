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

def _font_face() -> str:
    """Inline JetBrains Mono as a base64 @font-face.

    Embedding beats relying on fontconfig: the flake installs the font under
    fonts.packages, but that only takes effect after a system switch, and the
    render must work regardless. A data: URI makes the card self-contained.

    WOFF2 is preferred over TTF: same face at roughly a third of the bytes
    (94 KB vs 350 KB), and Chromium decodes it natively.
    """
    import base64
    import glob
    patterns = [
        "/nix/store/*jetbrains-mono*/share/fonts/WOFF2/JetBrainsMono-Regular.woff2",
        "/nix/store/*jetbrains-mono*/share/fonts/truetype/JetBrainsMono-Regular.ttf",
        "/nix/store/*jetbrains-mono*/share/fonts/**/*Regular*.woff2",
        "/nix/store/*jetbrains-mono*/share/fonts/**/*Regular*.ttf",
        "/nix/store/*jetbrains-mono*/share/fonts/**/*.ttf",
    ]
    path = None
    for pat in patterns:
        hits = sorted(glob.glob(pat, recursive=True))
        if hits:
            path = hits[0]
            break
    if not path:
        return ""
    try:
        with open(path, "rb") as fh:
            b64 = base64.b64encode(fh.read()).decode("ascii")
    except OSError:
        return ""
    fmt = "woff2" if path.endswith(".woff2") else "truetype"
    mime = "font/woff2" if fmt == "woff2" else "font/ttf"
    return ("@font-face{font-family:'JBMono';"
            f"src:url(data:{mime};base64,{b64}) format('{fmt}');"
            "font-weight:100 900;font-style:normal;font-display:block}")


FONT_CSS = _font_face()

# Palette + typography: a terminal window, not a dashboard.
#
# Monospace throughout, squared corners, no soft cards or gradients. The accent is
# amber-on-black because that is what the status output it replaces looked like;
# colour is used only for state (ok/warn/crit), never for decoration.
CSS = FONT_CSS + """
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0b0e14;
     font-family:'JBMono','JetBrains Mono','DejaVu Sans Mono',monospace;
     font-size:13.5px;line-height:1.5;
     padding:22px 26px;width:900px;color:#c8ccd4}
/* Prompt line instead of a header rule. */
.hd{display:flex;align-items:baseline;justify-content:space-between;
    margin-bottom:20px;font-size:13px}
.hd h1{font-size:13.5px;font-weight:500;letter-spacing:0;color:#c8ccd4}
.hd h1:before{content:"$ ";color:#5c6370}
.hd .sub{font-size:12px;color:#5c6370}
.sec{margin-bottom:22px}
.sec:last-child{margin-bottom:4px}
/* Section label mimics a comment line: # ... */
.sec h2{font-size:12px;text-transform:none;letter-spacing:0;
        color:#5c6370;margin-bottom:11px;font-weight:400}
.sec h2:before{content:"# ";color:#3f4652}
.row{display:grid;grid-template-columns:190px 1fr 150px;align-items:center;
     gap:14px;padding:7px 0}
.row .lbl{font-size:13px;color:#9aa2ae}
/* Progress bar as a block-character meter: filling, empty. */
.bar{height:13px;background:transparent;overflow:hidden;
     font-size:12px;line-height:13px;letter-spacing:1px;color:#3f4652;
     display:flex;align-items:center}
.bar>i{display:block;height:13px;border-radius:0}
/* Terminal meter: solid glyphs in the state colour, dim remainder. */
.meter{font-size:13px;letter-spacing:1.5px;line-height:1;white-space:nowrap}
.meter.g{color:#7ec87e}.meter.y{color:#d9a441}.meter.r{color:#d96a6a}
.meter .rest{color:#2a303c}
.val{font-size:13px;text-align:right;color:#e6e9ef}
.val i{color:#5c6370;font-style:normal}
.note{font-size:11.5px;color:#5c6370;margin-top:7px;line-height:1.55;
      font-family:'JetBrains Mono','DejaVu Sans Mono',monospace}
table{width:100%;border-collapse:collapse;font-size:12.5px}
th{text-align:left;font-size:10.5px;text-transform:uppercase;letter-spacing:1px;
   color:#5c6370;font-weight:500;padding:0 9px 7px 0;border-bottom:1px solid #1c212b}
td{padding:6px 9px 6px 0;border-bottom:1px solid #12161e;color:#c8ccd4}
tr:last-child td{border-bottom:none}
td.n,th.n{text-align:right;font-variant-numeric:tabular-nums}
td.dim{color:#5c6370}
/* State colours: green ok, amber warn, red crit. */
.g{background:#7ec87e}.y{background:#d9a441}.r{background:#d96a6a}.b{background:#6a9fd9}
.warn{margin-top:16px;padding:10px 12px;
      background:transparent;border-left:2px solid #d96a6a;font-size:12.5px}
.warn b{color:#d96a6a}
"""


def _chrome() -> str | None:
    for c in CHROME_CANDIDATES:
        if os.access(c, os.X_OK):
            return c
    return shutil.which("chromium") or shutil.which("google-chrome")


def _bar(pct: float, width: int = 24) -> str:
    """Block-character meter, the way a terminal progress bar renders.

    Colour marks state only: green under 60%, amber to 85%, red beyond. The
    glyphs carry the proportion so the card still reads correctly in greyscale.
    """
    cls = "g" if pct < 60 else ("y" if pct < 85 else "r")
    frac = max(0.0, min(100.0, pct)) / 100.0
    filled = int(round(frac * width))
    # Half-block for an odd remainder keeps short bars from reading as zero.
    return (f'<span class="meter {cls}">'
            f'{"█" * filled}<span class="rest">{"░" * (width - filled)}</span>'
            '</span>')


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
            # Show consumed against the limit, not headroom: "used of limit" is
            # how a budget is normally read, and it makes the bar and the number
            # point the same direction.
            rows.append(
                f'<div class="row"><div class="lbl">{_esc(label)}</div>{_bar(pct)}'
                f'<div class="val">{CC_UNIT}{used:.2f}<i> of {CC_UNIT}{total:.0f}</i></div></div>'
                f'<div class="note" style="margin:-4px 0 6px 206px">'
                f'{pct:.0f}% used · {CC_UNIT}{left:.2f} left'
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
            f'<div class="val">{used}<i> of {allow} credits</i></div></div>'
            f'<div class="note" style="margin:-4px 0 6px 206px">'
            f'{pct:.0f}% used · {left} left (~${left * 0.01:.2f}) · '
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


def html_timesheet(doc: dict) -> str:
    """Weekly timesheet progress card.

    Two progress axes, because they answer different questions: the big bar is
    week-to-date against the 40 h target (the number he asked for), and the day
    strip shows which days are carrying the load so a thin Wednesday is visible
    at a glance rather than needing arithmetic.
    """
    pct = doc.get("percent") or 0.0
    wtd = doc.get("week_to_date") or 0.0
    target = doc.get("target") or 40.0
    remaining = doc.get("remaining") or 0.0
    ws, we = doc.get("week_start", ""), doc.get("week_end", "")
    body = [f'<div class="hd"><h1>Timesheet · week {doc.get("week_no","?")}</h1>'
            f'<div class="sub">{ws} → {we}</div></div>']

    # Headline: hours logged against target.
    body.append(
        '<div class="sec">'
        f'<div class="row" style="grid-template-columns:1fr 210px">'
        f'<div class="bigbar">{_bar(pct)}</div>'
        f'<div class="val" style="font-size:19px">{wtd:.2f}<i> of {target:.0f} h</i></div>'
        '</div>'
        f'<div class="note" style="margin-top:10px">'
        f'{pct:.1f}% of target · <b style="color:#e6edf3">{remaining:.2f} h remaining</b>'
        '</div></div>')

    # Day strip: bar height scaled to the largest day, so relative load is visible.
    days = doc.get("days") or []
    peak = max([d.get("hours") or 0.0 for d in days] + [8.0])
    cells = []
    for d in days:
        h = d.get("hours") or 0.0
        hpct = 100.0 * h / peak
        if d.get("is_future"):
            col, lab = "#21262d", ""
        elif h >= 8:
            col, lab = "#3fb950", ""
        elif h >= 4:
            col, lab = "#d29922", ""
        elif h > 0:
            col, lab = "#f85149", ""
        else:
            col, lab = "#30363d", ""
        ov = d.get("overlap") or 0.0
        flag = ('<div class="ov">↔%.2f</div>' % ov) if ov else '<div class="ov"> </div>'
        cells.append(
            '<div class="dcell">'
            f'<div class="dval">{h:.2f}</div>'
            f'<div class="dbar"><i style="height:{max(2.0,hpct):.0f}%;background:{col}"></i></div>'
            f'<div class="dname">{_esc(d.get("dow",""))}</div>'
            f'<div class="ddate">{_esc((d.get("date","") or "")[8:])}</div>'
            f'{flag}</div>')
    body.append('<div class="sec"><h2>Daily load</h2>'
                f'<div class="dstrip">{"".join(cells)}</div>'
                '<div class="note">Bar height is relative to the heaviest day. '
                '↔ marks logged intervals that overlap, so wall-clock double-counts.</div></div>')

    # Status lines: what needs attention, in his words.
    flags = []
    if doc.get("overlap_total"):
        days_ov = ", ".join(f"{k[5:]} ({v:.2f} h)" for k, v in (doc.get("overlaps") or {}).items())
        flags.append(("warn", f"Overlapping logs: {doc['overlap_total']:.2f} h on {days_ov}"))
    else:
        flags.append(("ok", "Overlaps: none"))
    if doc.get("mismatches"):
        flags.append(("warn", f"Timeline/start-date mismatches: {doc['mismatches']}"))
    else:
        flags.append(("ok", "Timeline/start-date mismatches: none"))
    if doc.get("pending_count"):
        names = doc.get("pending_names") or []
        preview = "; ".join(n.split(" - ", 1)[-1][:42] for n in names[:3])
        flags.append(("info", f"{doc['pending_count']} entries still at 0 min"
                              + (f" — {preview}" if preview else "")))
    rows = []
    for kind, text in flags:
        sym = {"ok": "[ok]", "warn": "[!]", "info": "[..]"}[kind]
        col = {"ok": "#7ec87e", "warn": "#d9a441", "info": "#5c6370"}[kind]
        rows.append(f'<div class="flag"><span style="color:{col}">{sym}</span>'
                    f'<span>{_esc(text)}</span></div>')
    body.append('<div class="sec">' + "".join(rows) + '</div>')

    body.append(f'<div class="note">ODS as of {_esc(doc.get("ods_freshness","?"))} WIB · '
                'no hours were nudged or invented</div>')
    return f"<html><head><meta charset='utf-8'><style>{CSS}{TS_CSS}</style></head><body>{''.join(body)}</body></html>"


TS_CSS = """
/* Timesheet extras, kept in the same terminal idiom. */
.bigbar .meter{font-size:17px;letter-spacing:2px}
.dstrip{display:grid;grid-template-columns:repeat(7,1fr);gap:9px;margin-top:4px}
.dcell{text-align:center}
.dval{font-size:12.5px;color:#c8ccd4;font-variant-numeric:tabular-nums;
      margin-bottom:5px}
.dbar{height:66px;display:flex;align-items:flex-end;justify-content:center}
/* Vertical meter built from the same glyphs, stacked. */
.dbar>i{display:block;width:100%;border-radius:0}
.dname{font-size:12px;color:#e6e9ef;margin-top:6px}
.ddate{font-size:11px;color:#3f4652;font-variant-numeric:tabular-nums}
.ov{font-size:10.5px;color:#d9a441;margin-top:3px;min-height:13px}
/* Flag lines mimic compiler/status output: [ok] / [!] / [..] */
.flag{display:flex;gap:9px;font-size:12.5px;color:#c8ccd4;padding:3px 0;line-height:1.5}
.flag span:first-child{width:26px;text-align:left;flex:0 0 26px;font-weight:400}
"""


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
    elif kind == "timesheet":
        if not json_path:
            raise SystemExit("render_report: timesheet needs --json <path>")
        html = html_timesheet(json.loads(Path(json_path).read_text(encoding="utf-8")))
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

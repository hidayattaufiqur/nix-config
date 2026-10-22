import re
import sys

# Targeted, formatting-preserving edit of a worker profile's config.yaml.
# NOT a yaml round-trip: these files are CLI-owned and a safe_dump would
# reorder every key and drop the file's existing layout.

for prof in ("atlas", "dossier"):
    path = f"/var/lib/hermes/.hermes/profiles/{prof}/config.yaml"
    try:
        with open(path) as f:
            text = f.read()
    except OSError as e:
        print(f"{prof}: SKIP ({e})")
        continue

    changed = []

    # 1) approvals.mode -> off + timeout 1800. Inserted right after
    #    "approvals:" when missing; replaced in place when present.
    am = re.search(r"^approvals:\s*$", text, re.M)
    if am:
        blk_start = am.end()
        # approvals block ends at the next non-indented top-level key
        nxt = re.search(r"^[^\s#\n]", text[blk_start:], re.M)
        blk_end = blk_start + nxt.start() if nxt else len(text)
        block = text[blk_start:blk_end]
        if re.search(r"^(\s*)mode:", block, re.M):
            # Quoted: YAML 1.1 parses bare `off` as boolean False. Hermes
            # normalises that back to "off", but quoting keeps it a string
            # for every other YAML consumer too.
            new_block = re.sub(r"^(\s*)mode:.*$", r"\1mode: 'off'", block, count=1, flags=re.M)
        else:
            new_block = "\n  mode: 'off'" + block
        if re.search(r"^(\s*)timeout:", new_block, re.M):
            new_block = re.sub(r"^(\s*)timeout:.*$", r"\1timeout: 1800", new_block, count=1, flags=re.M)
        else:
            new_block = new_block.rstrip("\n") + "\n  timeout: 1800\n"
        if new_block != block:
            text = text[:blk_start] + new_block + text[blk_end:]
            changed.append("approvals.mode/timeout")
    else:
        text = text.rstrip("\n") + "\napprovals:\n  mode: 'off'\n  timeout: 1800\n"
        changed.append("approvals block added")

    # 3) plugins.enabled -> add jev-gate
    pm = re.search(r"^plugins:\s*$", text, re.M)
    if pm:
        pstart = pm.start()
        pnxt = text.find("\n[^\s]", pstart + 1)
        pblock = text[pstart: pnxt if pnxt != -1 else len(text)]
        em = re.search(r"^(\s*)enabled:\s*$", pblock, re.M)
        if em:
            indent = em.group(1) + "  "
            if "jev-gate" not in pblock:
                ins = pstart + em.end() + 1
                text = text[:ins] + indent + "- jev-gate\n" + text[ins:]
                changed.append("plugins.enabled += jev-gate")
        else:
            pstart = pm.start()
            ins = pstart + len("plugins:\n")
            text = text[:ins] + "  enabled:\n    - jev-gate\n" + text[ins:]
            changed.append("plugins block added")
    else:
        text += "\nplugins:\n  enabled:\n    - jev-gate\n  disabled: []\n"
        changed.append("plugins block added")

    # Only write when something actually changed. An unconditional write
    # would bump the mtime every switch, and config.yaml is a
    # restartTrigger -> the worker gateway would restart on every rebuild.
    if changed:
        with open(path, "w") as f:
            f.write(text)
    print(f"{prof}: {changed if changed else 'already wired'}")

sys.exit(0)

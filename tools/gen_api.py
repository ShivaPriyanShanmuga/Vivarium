#!/usr/bin/env python3
"""Generate docs/creature-api.md from the runtime GDScript type definitions, so the agent's
context reference (§6.1) cannot go stale. Extracts class_name, the class doc (## block), and
public func signatures with their ## doc comments."""
import re, glob, os, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
FILES = sorted(glob.glob(os.path.join(ROOT, "runtime", "*.gd"))) + [
    os.path.join(ROOT, "addons", "vivarium", "agent", "viv_tools.gd"),
    os.path.join(ROOT, "addons", "vivarium", "host", "viv_creature_runner.gd"),
]

def parse(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    cls = None
    class_doc = []
    funcs = []
    consts = []
    pending = []
    seen_class = False
    for ln in lines:
        s = ln.strip()
        m = re.match(r"class_name\s+(\w+)", s)
        if m:
            cls = m.group(1); continue
        if s.startswith("##"):
            pending.append(s[2:].strip()); continue
        # class doc = first ## block after class_name/extends, before any func
        if cls and not seen_class and s.startswith("extends"):
            continue
        mf = re.match(r"(static\s+)?func\s+([a-zA-Z]\w*)\s*\((.*?)\)\s*(->\s*[\w\[\].]+)?", s)
        if mf and not mf.group(2).startswith("_"):
            ret = (mf.group(4) or "").replace("->", "").strip()
            sig = f"{mf.group(2)}({mf.group(3)})" + (f" -> {ret}" if ret else "")
            funcs.append((("static " if mf.group(1) else "") + sig, " ".join(pending)))
            pending = []; seen_class = True; continue
        mc = re.match(r"const\s+([A-Z]\w*)\s*(:=|=)\s*(.+)", s)
        if mc:
            consts.append((mc.group(1), mc.group(3).strip())); pending = []; continue
        mv = re.match(r"var\s+([a-zA-Z]\w*)\s*:?\s*([\w\[\]]+)?", s)
        if mv and not mv.group(1).startswith("_") and not seen_class:
            # class-level public var
            consts.append(("var " + mv.group(1) + (": " + mv.group(2) if mv.group(2) else ""), ""))
            pending = []
            continue
        if s.startswith("func ") or (s and not s.startswith("#")):
            if not seen_class and cls and not class_doc and pending:
                class_doc = pending[:]
            if s.startswith("func "):
                seen_class = True
            pending = [] if s and not s.startswith("##") else pending
    # class doc fallback: first pending block captured right after class_name
    return cls, class_doc, consts, funcs

out = ["# Vivarium creature API reference",
       "",
       "> **Generated** from the runtime type definitions by `tools/gen_api.py` — do not",
       "> hand-edit; re-run to regenerate. This is the compact, exhaustive reference the agent",
       "> receives (§6.1), plus the host/tool surface.",
       ""]

# Re-parse capturing the class doc as the ## block immediately preceding the first func/const.
def parse2(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    cls_m = re.search(r"class_name\s+(\w+)", text)
    cls = cls_m.group(1) if cls_m else os.path.basename(path)[:-3]
    # class doc: ## lines right after the class_name/extends header
    doc = []
    lines = text.split("\n")
    started = False
    for ln in lines:
        s = ln.strip()
        if re.match(r"class_name|extends|@tool", s) or s == "":
            if doc: break
            started = True
            continue
        if s.startswith("##"):
            doc.append(s[2:].strip()); started = True
        elif started and doc:
            break
    # public funcs with preceding ## comment
    funcs = []
    pending = []
    for ln in lines:
        s = ln.strip()
        if s.startswith("##"):
            pending.append(s[2:].strip()); continue
        mf = re.match(r"(static\s+)?func\s+([a-zA-Z]\w*)\s*\((.*?)\)\s*(->\s*[\w\[\].]+)?", s)
        if mf and not mf.group(2).startswith("_"):
            ret = (mf.group(4) or "").replace("->", "").strip()
            sig = ("static " if mf.group(1) else "") + f"{mf.group(2)}({mf.group(3)})" + (f" -> {ret}" if ret else "")
            funcs.append((sig, " ".join(pending)))
            pending = []
        elif s and not s.startswith("#"):
            pending = []
    return cls, doc, funcs

for path in FILES:
    if not os.path.exists(path):
        continue
    cls, doc, funcs = parse2(path)
    rel = os.path.relpath(path, ROOT).replace("\\", "/")
    out.append(f"## `{cls}`  \n`{rel}`")
    out.append("")
    if doc:
        out.append(" ".join(doc))
        out.append("")
    if funcs:
        for sig, cm in funcs:
            out.append(f"- `{sig}`" + (f" — {cm}" if cm else ""))
        out.append("")

with open(os.path.join(ROOT, "docs", "creature-api.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("wrote docs/creature-api.md  (%d classes)" % sum(1 for p in FILES if os.path.exists(p)))

#!/usr/bin/env python3
"""Throwaway ring reference. python3 .scratch/quotai/prototype/ring-dimensions/run.py"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import webbrowser

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def build():
    ring = (ROOT / "QuotAI/RingIcon.swift").read_text()
    presentation = (ROOT / "QuotAICore/Sources/MenuPresentation.swift").read_text()
    enums = presentation[presentation.index("public enum IconColorMode"):presentation.index("/// How far off")]
    def metric(name):
        return float(re.search(r"let " + name + r": CGFloat = (-?[\d.]+)", ring)[1])
    m = {k: metric(k) for k in ["height", "midY", "ringD", "ringGap", "metricGap", "outerR", "timelineStroke", "quotaStroke", "ringGapStroke", "dualFontSize", "dualLineOffset", "besideKern"]}
    if m["height"] != 22 or m["timelineStroke"] != .8:
        print("Production geometry has changed. Preserving the original native snapshots; adjusted previews use live SVG.", flush=True)
        return
    # Preserve timeline INNER edge, hence preserve the entire usage ring + air gap.
    doubled = ring.replace("enum RingIcon {", "enum RingIconDouble {")
    for name, value in [("outerR", m["outerR"] + m["timelineStroke"] / 2), ("timelineStroke", m["timelineStroke"] * 2), ("ringD", m["ringD"] + m["timelineStroke"] * 2)]:
        doubled = re.sub(r"let " + name + r": CGFloat = [\d.]+", f"let {name}: CGFloat = {value:.8f}", doubled)
    sources = [enums]
    for file in ["QuotaPercent", "RemainingTime", "PaceCalculator", "RingDialSegments"]:
        sources.append((ROOT / f"QuotAICore/Sources/{file}.swift").read_text())
    sources += [(ROOT / "QuotAI/BarIcon.swift").read_text(), ring, doubled, (HERE / "render.swift").read_text()]
    combined = "\n".join(sources).replace("import QuotAICore", "")
    assets = HERE / "assets"
    assets.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="quotai-ring-reference-") as temp:
        source = Path(temp) / "main.swift"
        source.write_text(combined)
        executable = Path(temp) / "render"
        subprocess.run(["swiftc", "-module-cache-path", str(Path(temp) / "cache"), str(source), "-o", str(executable)], check=True)
        subprocess.run([str(executable), str(assets)], check=True)
    generated = json.loads((assets / "native.json").read_text())
    definitions = {}
    for name in m:
        line = next((i, line.strip()) for i, line in enumerate(ring.splitlines(), 1) if re.search(r"let " + name + r": CGFloat =", line))
        definitions[name] = {"line": line[0], "definition": line[1]}
    generated.update(metrics=m, sourceDefinitions=definitions, sourceSHA256=hashlib.sha256(ring.encode()).hexdigest())
    (assets / "data.js").write_text("window.REFERENCE = " + json.dumps(generated, indent=2) + ";\n")
    print("Native AppKit assets generated; application source unchanged.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()
    build()
    if not args.build_only:
        url = (HERE / "index.html").as_uri() + "?variant=B"
        print(url, flush=True)
        if not args.no_open:
            webbrowser.open(url)

#!/usr/bin/env python3
"""Download the newest CIEL release of every open PDK family.

CIEL publishes pre-built PDKs as GitHub release assets, one zstd-compressed
tarball per library, plus a `common` tarball.  This script picks the newest
release of each family (the first entry of the same manifest `ciel ls-remote`
reads) and stores the assets unmodified:

    archives/<family>-<version>/<asset>

`archives/versions.json` records the versions, the asset URLs and their
sha256, so the payload can be re-checked and unpacked unattended.
"""
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
import urllib.request

BASE = "https://fossi-foundation.github.io/ciel-releases"
DEFAULT_DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "archives")
VARIANTS = {
    "sky130": ["sky130A", "sky130B"],
    "gf180mcu": ["gf180mcuA", "gf180mcuB", "gf180mcuC", "gf180mcuD"],
    "ihp-sg13": ["ihp-sg13g2", "ihp-sg13cmos5l"],
    "freepdk45": ["freepdk45"],
}


def get_json(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return json.load(r)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and os.path.getsize(path):
        return path
    tmp = path + ".partial"
    cmd = ["curl", "-fL", "--retry", "10", "--retry-delay", "5",
           "--no-progress-meter"]
    if os.path.exists(tmp) and os.path.getsize(tmp):
        cmd += ["-C", "-"]
    subprocess.run(cmd + ["-o", tmp, url], check=True)
    os.replace(tmp, path)
    return path


def fetch_family(family, dest):
    versions = get_json(f"{BASE}/{family}/manifest.json")["versions"]
    latest = versions[0]  # newest first, same order as `ciel ls-remote`
    version = latest["version"]
    manifest = get_json(f"{BASE}/{family}/{version}/manifest.json")
    tag = f"{family}-{version}"
    out = os.path.join(dest, tag)
    print(f"[{tag}] {len(manifest['assets'])} assets", flush=True)
    assets = []
    for asset in manifest["assets"]:
        path = download(asset["url"], os.path.join(out, asset["filename"]))
        size = os.path.getsize(path)
        print(f"  {tag}/{asset['filename']} {size / 2**20:.1f} MiB", flush=True)
        assets.append({**asset, "size": size, "sha256": sha256(path)})
    return {
        "family": family,
        "version": version,
        "date": latest["date"],
        "prerelease": latest.get("prerelease", False),
        "variants": VARIANTS[family],
        "assets": assets,
    }


def main():
    dest = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DEST
    families = sys.argv[2:] or sorted(VARIANTS)
    os.makedirs(dest, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(len(families)) as ex:
        entries = list(ex.map(lambda f: fetch_family(f, dest), families))
    index_path = os.path.join(dest, "versions.json")
    known = {}
    if os.path.exists(index_path):
        try:
            known = {e["family"]: e for e in json.load(open(index_path))}
        except ValueError:
            known = {}
    known.update({e["family"]: e for e in entries})
    with open(index_path, "w") as f:
        json.dump([known[k] for k in sorted(known)], f, indent=2)
        f.write("\n")
    for e in sorted(entries, key=lambda e: e["family"]):
        flag = " (prerelease)" if e["prerelease"] else ""
        print(f"{e['family']}: {e['version']} ({e['date']}){flag}", flush=True)


if __name__ == "__main__":
    main()

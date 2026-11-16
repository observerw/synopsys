#!/usr/bin/env python3
"""Unpack the downloaded CIEL release assets into a PDK root tree.

This reproduces what `ciel enable` installs, without running ciel itself:

    <root>/ciel/<family>/versions/<version>/<variant>/...
    <root>/ciel/<family>/current
    <root>/<variant> -> ciel/<family>/versions/<version>/<variant>
    <root>/versions.json

The relative symlinks are the ones `ciel enable` creates, so PDK_ROOT=<root>
and every variant name resolve.  The result is the build context of
Containerfile.pdk.
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ARCHIVES = os.path.join(HERE, "archives")
DEFAULT_ROOT = os.path.join(HERE, "pdk")


def main():
    archives = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ARCHIVES
    root = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_ROOT
    index = os.path.join(archives, "versions.json")
    entries = json.load(open(index))

    if os.path.exists(root):
        print(f"removing previous tree {root}", flush=True)
        shutil.rmtree(root)
    os.makedirs(root)

    for entry in entries:
        family, version = entry["family"], entry["version"]
        src = os.path.join(archives, f"{family}-{version}")
        version_dir = os.path.join(root, "ciel", family, "versions", version)
        os.makedirs(version_dir, exist_ok=True)
        for asset in entry["assets"]:
            path = os.path.join(src, asset["filename"])
            print(f"unpacking {family}/{version}/{asset['filename']}", flush=True)
            subprocess.run(["tar", "--zstd", "-xf", path, "-C", version_dir], check=True)
        current = os.path.join(root, "ciel", family, "current")
        with open(current, "w") as f:
            f.write(version + "\n")
        for variant in entry["variants"]:
            vdir = os.path.join(version_dir, variant)
            if os.path.isdir(vdir):
                os.symlink(os.path.relpath(vdir, root), os.path.join(root, variant))

    shutil.copyfile(index, os.path.join(root, "versions.json"))
    print(f"PDK root ready at {root}", flush=True)


if __name__ == "__main__":
    main()

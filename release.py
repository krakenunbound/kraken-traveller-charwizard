#!/usr/bin/env python3
"""Build and publish a GitHub Release for the Kraken Traveller Character Wizard.

Builds KrakenTravellerCharWizard.ext from the extension files in this repository
(extension.xml, graphics, scripts, strings, xml) and creates (or updates) a
GitHub Release with it attached.

Usage:
    python release.py                 # tag = "v" + version from extension.xml
    python release.py v1.0-beta1      # explicit tag
    python release.py --sync          # first copy the extension files from
                                      # <FG data>/extensions/KrakenCharWizardMGT2
    python release.py --build-only    # build the .ext, no release

Requires: Python 3 and, to publish, the GitHub CLI (`gh`) authenticated.
"""
import os, sys, shutil, subprocess, zipfile
import xml.etree.ElementTree as ET

REPO  = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(REPO, "build")
LIVE  = os.path.abspath(os.path.join(REPO, "..", "..", "extensions", "KrakenCharWizardMGT2"))
EXT   = "KrakenTravellerCharWizard.ext"

# Everything FGU needs, nothing else.
INCLUDE = ["extension.xml", "graphics", "scripts", "strings", "xml"]
# Files in the live folder that the extension does not load.
SKIP = set()


def version():
    r = ET.parse(os.path.join(REPO, "extension.xml")).getroot()
    return r.findtext("properties/version") or r.get("version") or "0.0.0"


def files(root):
    for item in INCLUDE:
        p = os.path.join(root, item)
        if os.path.isfile(p):
            yield item
        elif os.path.isdir(p):
            for d, _, fs in os.walk(p):
                for f in fs:
                    rel = os.path.relpath(os.path.join(d, f), root).replace("\\", "/")
                    if rel not in SKIP:
                        yield rel


def sync():
    if not os.path.isdir(LIVE):
        raise SystemExit(f"live extension not found: {LIVE}")
    for item in INCLUDE[1:]:
        shutil.rmtree(os.path.join(REPO, item), ignore_errors=True)
    n = 0
    for rel in files(LIVE):
        dest = os.path.join(REPO, rel)
        os.makedirs(os.path.dirname(dest) or REPO, exist_ok=True)
        shutil.copyfile(os.path.join(LIVE, rel), dest)
        n += 1
    print(f"[sync] {n} files from {LIVE}")


def build_ext(dest):
    n = 0
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files(REPO):
            z.write(os.path.join(REPO, rel), rel)
            n += 1
    with zipfile.ZipFile(dest) as z:
        assert "extension.xml" in z.namelist(), "extension.xml not at .ext root"
    return n


def main():
    args = list(sys.argv[1:])
    notes = None
    if "--notes" in args:
        i = args.index("--notes"); notes = args[i + 1]; del args[i:i + 2]
    if "--sync" in args:
        args.remove("--sync"); sync()
    build_only = "--build-only" in args
    if build_only:
        args.remove("--build-only")
    tag = args[0] if args else ("v" + version())

    os.makedirs(BUILD, exist_ok=True)
    out = os.path.join(BUILD, EXT)
    n = build_ext(out)
    print(f"[build] {EXT}  ({n} files, {os.path.getsize(out) / 1e6:.1f} MB)")
    if build_only:
        return

    title = f"Kraken Traveller Character Wizard {tag}"
    if not notes:
        notes = (f"{title}\n\n"
                 f"Install: {EXT} -> Fantasy Grounds \\extensions\\. Requires FGU, SmiteWorks' "
                 "Mongoose Traveller 2E ruleset (MGT2) and the MGT2 Core Rulebook or Players Reference "
                 "module loaded in the campaign. See CHANGELOG.md.")
    exists = subprocess.run(["gh", "release", "view", tag], cwd=REPO,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if exists:
        print(f"[gh] release {tag} exists -> uploading the .ext (--clobber)")
        subprocess.run(["gh", "release", "upload", tag, out, "--clobber"], cwd=REPO, check=True)
    else:
        print(f"[gh] creating release {tag}")
        subprocess.run(["gh", "release", "create", tag, out, "--title", title, "--notes", notes],
                       cwd=REPO, check=True)
    print("[done]", tag)


if __name__ == "__main__":
    main()

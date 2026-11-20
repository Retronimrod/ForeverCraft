"""Build an optional ForeverCraft release with fresh Forever skill thresholds."""

import argparse
import hashlib
import io
import json
import os
import re
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZIP_DEFLATED, ZipFile

API = "https://api.curseforge.com/v1/mods/1558781/files"
ROOT = Path(__file__).resolve().parents[1]
CORE_FILE = re.compile(r"ProfessionDB/Data/Forever/_core/[^/]+\.lua")
RECIPE = re.compile(r"^\t\t\[(\d+)\] = \{\s*\n(.*?)^\t\t\},", re.M | re.S)
DIFFICULTY = re.compile(r'\["difficulty"\] = \{\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),?\s*\}')
SNAPSHOT_ROW = re.compile(r"\[(\d+)\] = \{ (\d+), (\d+), (\d+) \}")


def fetch_forever_archive(key):
    request = Request(f"{API}?gameVersion=1.60.1&pageSize=50", headers={"x-api-key": key})
    with urlopen(request, timeout=30) as response:
        files = json.load(response)["data"]
    candidates = [
        file for file in files
        if file["releaseType"] == 1 and "1.60.1" in file["gameVersions"] and file.get("downloadUrl")
    ]
    if not candidates:
        raise ValueError("No downloadable stable WoW Forever file found")
    latest = max(candidates, key=lambda file: (file["fileDate"], file["id"]))
    with urlopen(latest["downloadUrl"], timeout=60) as response:
        archive = response.read()
    sha1 = next((entry["value"] for entry in latest.get("hashes", []) if entry["algo"] == 1), None)
    if sha1 and hashlib.sha1(archive).hexdigest() != sha1.lower():
        raise ValueError("CurseForge archive checksum does not match")
    return archive


def read_thresholds(archive):
    rows, builds = {}, set()
    with ZipFile(io.BytesIO(archive)) as source:
        toc = source.read("ProfessionDB/ProfessionDB_Camelot.toc").decode("utf-8-sig")
        version = re.search(r"^## Version: ProfessionDB-v([\d.]+)\s*$", toc, re.M)
        if not version:
            raise ValueError("Cannot identify the LibProfessionDB version")
        for name in source.namelist():
            if not CORE_FILE.fullmatch(name):
                continue
            content = source.read(name).decode("utf-8-sig").replace("\r\n", "\n")
            if "lib:LoadCore(" not in content:
                continue
            build = re.search(r"^-- build (\d+\.\d+\.\d+\.\d+) - (\d+) recipes\s*$", content, re.M)
            recipe_block = content.split("lib:LoadCore(", 1)[1].split("\n\t})", 1)[0]
            recipes = RECIPE.findall(recipe_block)
            if not build or len(recipes) != int(build[2]):
                raise ValueError(f"Recipe layout or count changed in {name}")
            builds.add(build[1])
            for recipe_id, fields in recipes:
                match = DIFFICULTY.search(fields)
                if not match:
                    continue
                _, yellow, green, gray = map(int, match.groups())
                if 0 < yellow <= green <= gray:
                    rows[int(recipe_id)] = (yellow, green, gray)
        license_text = source.read("ProfessionDB/LICENSE")
    if len(builds) != 1 or not rows:
        raise ValueError("Missing recipe data or inconsistent WoW Forever builds")
    return version[1], builds.pop(), rows, license_text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Use a local LibProfessionDB ZIP")
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    parser.add_argument("--force", action="store_true", help="Build even if recipe thresholds match")
    args = parser.parse_args()
    archive = args.archive.read_bytes() if args.archive else fetch_forever_archive(os.environ["CURSEFORGE_API_KEY"])
    upstream, build, rows, license_text = read_thresholds(archive)
    addon = ROOT / "ForeverCraft"
    current = (addon / "SkillThresholdData.lua").read_text()
    old_rows = {int(row[0]): tuple(map(int, row[1:])) for row in SNAPSHOT_ROW.findall(current)}
    if len(rows) < len(old_rows) * 0.9:
        raise ValueError(f"Import lost too many recipe thresholds: {len(old_rows)} → {len(rows)}")
    output = os.environ.get("GITHUB_OUTPUT")
    if rows == old_rows and not args.force:
        print(f"Skill thresholds match the bundled snapshot ({len(rows)} recipes).")
        if output:
            with open(output, "a") as handle:
                handle.write("changed=false\n")
        return

    data = "".join(f"    [{key}] = {{ {a}, {b}, {c} }},\n" for key, (a, b, c) in sorted(rows.items()))
    digest = hashlib.sha256(data.encode()).hexdigest()[:10]
    toc = (addon / "ForeverCraft_Forever.toc").read_text()
    base = re.search(r"^## Version: (\S+)$", toc, re.M)[1]
    version = f"{base}.db.{upstream}.{digest}"
    snapshot = (
        f"-- Skill tiers from LibProfessionDB {upstream}, WoW Forever build {build}.\n"
        "-- Copyright (c) 2026 Pimptasty. See LibProfessionDB-LICENSE.txt.\n"
        'local _, addon = ...\naddon.skillThresholdData = {\n' + data + "}\n"
    )
    args.output.mkdir(parents=True, exist_ok=True)
    bundle = args.output / f"ForeverCraft-v{version}.zip"
    with ZipFile(bundle, "w", ZIP_DEFLATED) as package:
        for path in sorted(addon.rglob("*")):
            if not path.is_file():
                continue
            target = path.relative_to(ROOT).as_posix()
            if path.name == "SkillThresholdData.lua":
                package.writestr(target, snapshot)
            elif path.name == "LibProfessionDB-LICENSE.txt":
                package.writestr(target, license_text)
            elif path.name in {"Core.lua", "README.txt", "ForeverCraft_Forever.toc"}:
                package.writestr(target, path.read_text().replace(base, version))
            else:
                package.write(path, target)
    if output:
        with open(output, "a") as handle:
            handle.write(f"changed=true\ntag=v{version}\narchive={bundle}\nupstream={upstream}\nbuild={build}\n")
    print(f"{bundle} ({len(rows)} recipes, LibProfessionDB {upstream}, WoW build {build})")


if __name__ == "__main__":
    main()

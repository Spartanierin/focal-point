#!/usr/bin/env python3
"""Generate the Focal Point decoration media manifest."""

from __future__ import annotations

import re
from pathlib import Path


SUPPORTED_EXTENSIONS = {".blp", ".png", ".tga"}


def normalize_id(filename: str) -> str:
    stem = Path(filename).stem.lower()
    stem = re.sub(r"[^a-z0-9]+", "-", stem).strip("-")
    if stem.startswith("fp-"):
        stem = stem[3:]
    return stem


def build_label(decoration_id: str) -> str:
    return " ".join(part.capitalize() for part in decoration_id.split("-") if part)


def discover_entries(decorations_dir: Path) -> list[dict[str, str]]:
    entries = []
    seen: dict[str, str] = {}

    for path in sorted(decorations_dir.iterdir(), key=lambda item: item.name.lower()):
        if not path.is_file() or path.name.startswith("."):
            continue
        if path.name.lower().startswith("readme"):
            continue
        if path.name == "DecorationManifest.lua":
            continue

        extension = path.suffix.lower()
        if extension not in SUPPORTED_EXTENSIONS:
            continue

        decoration_id = normalize_id(path.name)
        if not decoration_id:
            raise SystemExit(f"Could not derive decoration id from {path.name}")
        if decoration_id in seen:
            raise SystemExit(f"Duplicate decoration id '{decoration_id}' from {seen[decoration_id]} and {path.name}")

        seen[decoration_id] = path.name
        entries.append({
            "id": decoration_id,
            "label": build_label(decoration_id),
            "file": path.name,
        })

    return sorted(entries, key=lambda item: item["id"])


def render_manifest(entries: list[dict[str, str]]) -> str:
    lines = [
        "local _, FocalPoint = ...",
        "",
        "-- AUTO-GENERATED. DO NOT EDIT.",
        "FocalPoint.DecorationManifest = {",
    ]

    for entry in entries:
        lines.extend([
            "    {",
            f'        id = "{entry["id"]}",',
            f'        label = "{entry["label"]}",',
            f'        file = "{entry["file"]}",',
            "    },",
        ])

    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    decorations_dir = repo_root / "Media" / "Decorations"
    manifest_path = decorations_dir / "DecorationManifest.lua"

    if not decorations_dir.is_dir():
        raise SystemExit(f"Decoration directory not found: {decorations_dir}")

    manifest_path.write_text(render_manifest(discover_entries(decorations_dir)), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

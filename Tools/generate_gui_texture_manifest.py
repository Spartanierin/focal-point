#!/usr/bin/env python3
"""Generate the Focal Point GUI texture media manifest."""

from __future__ import annotations

import re
from pathlib import Path


SUPPORTED_EXTENSIONS = {".blp", ".png", ".tga"}


def normalize_id(filename: str) -> str:
    """Keep the full normalized stem so experiment variants do not collide."""
    stem = Path(filename).stem.lower()
    return re.sub(r"[^a-z0-9]+", "-", stem).strip("-")


def build_label(texture_id: str) -> str:
    parts = [part for part in texture_id.split("-") if part]
    if parts and parts[0] == "fp":
        parts[0] = "FP"
    return " ".join([parts[0]] + [part.capitalize() for part in parts[1:]]) if parts else ""


def discover_entries(texture_dir: Path) -> list[dict[str, str]]:
    entries = []
    seen: dict[str, str] = {}

    for path in sorted(texture_dir.iterdir(), key=lambda item: item.name.lower()):
        if not path.is_file() or path.name.startswith("."):
            continue
        if path.name == "GUITextureManifest.lua":
            continue
        if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
            continue

        texture_id = normalize_id(path.name)
        if not texture_id:
            raise SystemExit(f"Could not derive texture id from {path.name}")
        if texture_id in seen:
            raise SystemExit(f"Duplicate texture id '{texture_id}' from {seen[texture_id]} and {path.name}")

        seen[texture_id] = path.name
        entries.append({
            "id": texture_id,
            "label": build_label(texture_id),
            "file": path.name,
        })

    return sorted(entries, key=lambda item: item["id"])


def render_manifest(entries: list[dict[str, str]]) -> str:
    lines = [
        "local _, FocalPoint = ...",
        "",
        "-- AUTO-GENERATED. DO NOT EDIT.",
        "FocalPoint.GUITextureManifest = {",
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
    texture_dir = repo_root / "Media" / "Textures" / "GUI"
    manifest_path = texture_dir / "GUITextureManifest.lua"

    if not texture_dir.is_dir():
        raise SystemExit(f"GUI texture directory not found: {texture_dir}")

    manifest_path.write_text(render_manifest(discover_entries(texture_dir)), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

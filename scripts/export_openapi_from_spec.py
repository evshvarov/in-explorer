#!/usr/bin/env python3
"""Extract OpenAPI JSON from an InterSystems ObjectScript spec class."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def extract_openapi_json(spec_content: str) -> str:
    marker = "XData OpenAPI"
    marker_index = spec_content.find(marker)
    if marker_index == -1:
        raise ValueError("XData OpenAPI block was not found")

    xdata_start = spec_content.find("{", marker_index)
    if xdata_start == -1:
        raise ValueError("XData OpenAPI opening brace was not found")

    json_start = spec_content.find("{", xdata_start + 1)
    if json_start == -1:
        raise ValueError("OpenAPI JSON opening brace was not found")

    depth = 0
    json_end = -1
    for idx in range(json_start, len(spec_content)):
        char = spec_content[idx]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                json_end = idx
                break

    if json_end == -1:
        raise ValueError("OpenAPI JSON closing brace was not found")

    return spec_content[json_start : json_end + 1]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract OpenAPI JSON from spec.cls XData OpenAPI block."
    )
    parser.add_argument(
        "--input",
        default="src/esh/lcrm/api/spec.cls",
        help="Path to source spec.cls",
    )
    parser.add_argument(
        "--output",
        default="artifacts/openapi.json",
        help="Output path for extracted OpenAPI JSON",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    spec_content = input_path.read_text(encoding="utf-8")
    raw_json = extract_openapi_json(spec_content)

    parsed = json.loads(raw_json)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(parsed, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Exported OpenAPI spec to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

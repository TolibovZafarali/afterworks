#!/usr/bin/env python3
"""Export named native test screenshots without altering their pixels."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("result", type=Path, help="Completed .xcresult bundle")
parser.add_argument("prefix", help="Device name prefix, such as compact or large")
parser.add_argument("--output", type=Path, default=Path("artifacts/screenshots"))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="afterworks-captures-") as temporary:
    staging = Path(temporary)
    subprocess.run([
        "xcrun", "xcresulttool", "export", "attachments", "--path", str(args.result),
        "--output-path", str(staging),
    ], check=True)
    for test in json.loads((staging / "manifest.json").read_text()):
        for attachment in test["attachments"]:
            source = staging / attachment["exportedFileName"]
            name = attachment["suggestedHumanReadableName"].split("_0_")[0]
            if source.suffix == ".png" and name[:2].isdigit() and not attachment["isAssociatedWithFailure"]:
                destination = args.output / f"{args.prefix}-{name}.png"
                shutil.copyfile(source, destination)
                print(destination)

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_directory="$(mktemp -d "${TMPDIR:-/tmp}/afterworks-catalog.XXXXXX")"
trap 'rm -rf "$build_directory"' EXIT
swiftc -O Sources/AfterworksCore/*.swift scripts/generate-level-catalog.swift -o "$build_directory/catalog"
"$build_directory/catalog" "$@"
swift test --configuration release

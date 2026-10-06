#!/usr/bin/env bash
# Verifies that all version sources agree:
#   Cargo.toml  ==  extension/metadata.json "version-name"  [==  git tag, if given as $1 (vX.Y.Z)]
set -euo pipefail
cd "$(dirname "$0")/.."

cargo_version=$(sed -n 's/^version *= *"\(.*\)"/\1/p' Cargo.toml | head -n 1)
ext_version=$(python3 -c 'import json;print(json.load(open("extension/metadata.json"))["version-name"])')

[[ "$cargo_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
    echo "Cargo.toml version is not X.Y.Z: $cargo_version" >&2; exit 1; }
[[ "$cargo_version" == "$ext_version" ]] || {
    echo "Version mismatch: Cargo.toml=$cargo_version, metadata.json version-name=$ext_version" >&2; exit 1; }
if [[ -n "${1:-}" ]]; then
    [[ "${1#v}" == "$cargo_version" ]] || {
        echo "Tag $1 does not match version $cargo_version" >&2; exit 1; }
fi
echo "$cargo_version"

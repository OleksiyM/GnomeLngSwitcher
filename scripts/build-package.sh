#!/usr/bin/env bash
# Builds the release archive: dist/gnome-lng-switcher-<version>-<arch>.tar.gz
# Contents (single top-level directory):
#   gnome-lng-switcher, uninstall.sh, extension/, data/
# Environment: GLS_PACKAGE_ARCH overrides the detected architecture (x86_64 | aarch64).
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(./scripts/check-version.sh)
arch=${GLS_PACKAGE_ARCH:-$(uname -m)}
[[ $arch == arm64 ]] && arch=aarch64
case "$arch" in
    x86_64|aarch64) ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

package="gnome-lng-switcher-${version}-${arch}"
stage="dist/${package}"

cargo build --release --locked

rm -rf -- "$stage" "dist/${package}.tar.gz"
install -d "$stage/extension" "$stage/data"
install -m 0755 target/release/gnome-lng-switcher "$stage/gnome-lng-switcher"
install -m 0755 uninstall.sh "$stage/uninstall.sh"
install -m 0644 extension/metadata.json extension/extension.js extension/prefs.js "$stage/extension/"
install -m 0644 data/*.desktop.in "$stage/data/"
for doc in README.md LICENSE; do
    [[ -f "$doc" ]] && install -m 0644 "$doc" "$stage/$doc"
done

# Reproducible archive: sorted entries, fixed owner, commit timestamp, no gzip name/time.
epoch=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || date +%s)}
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="@${epoch}" \
    -cf - -C dist "$package" | gzip -n -9 > "dist/${package}.tar.gz"
rm -rf -- "$stage"
echo "dist/${package}.tar.gz"

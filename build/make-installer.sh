#!/bin/bash
# Builds the single-file installer out/installer/php56-hardened-<version>.run from the
# tested RPMs. Every package must match the checksums recorded in releases/, so the
# installer can only ever contain the exact files that were tested.
# Usage: bash build/make-installer.sh [version]      (default 1.0.0)
set -euo pipefail
VERSION="${1:-1.0.0}"
cd "$(dirname "$0")/.."

sha() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

OUT=out/installer
STAGE="$OUT/stage/php56-hardened"
RUN="$OUT/php56-hardened-$VERSION.run"
rm -rf "$OUT"
mkdir -p "$STAGE/hardened" "$STAGE/rollback"

copy_set() {  # source dir, recorded checksums, destination
  local n=0 f b want got
  for f in "$1"/*.x86_64.rpm; do
    b=$(basename "$f")
    case "$b" in *-debuginfo-*) continue ;; esac
    want=$(awk -v b="$b" '$2 == b { print $1 }' "$2")
    got=$(sha "$f" | cut -d' ' -f1)
    if [ -z "$want" ] || [ "$want" != "$got" ]; then
      echo "STOP: $b doesn't match the checksum recorded in $2" >&2; exit 1
    fi
    cp "$f" "$3/"; n=$((n + 1))
  done
  [ "$n" -gt 0 ] || { echo "STOP: no packages found in $1" >&2; exit 1; }
  echo "$n packages from $1 match $2"
}

copy_set out/rpms       releases/SHA256SUMS-hardened.txt "$STAGE/hardened"
copy_set out/rpms-stock releases/SHA256SUMS-stock.txt    "$STAGE/rollback"
cp install/verify.sh "$STAGE/"
( cd "$STAGE" && sha hardened/*.rpm rollback/*.rpm verify.sh > SHA256SUMS )

if tar --version 2>/dev/null | grep -q bsdtar; then   # macOS
  ( cd "$OUT/stage" && COPYFILE_DISABLE=1 tar --no-mac-metadata --uid 0 --gid 0 \
      --uname root --gname root -czf ../payload.tar.gz php56-hardened )
else                                                   # GNU tar
  ( cd "$OUT/stage" && tar --owner=0 --group=0 --numeric-owner -czf ../payload.tar.gz php56-hardened )
fi

PSUM=$(sha "$OUT/payload.tar.gz" | cut -d' ' -f1)
VERSION="$VERSION" PSUM="$PSUM" perl -pe 's/\@\@VERSION\@\@/$ENV{VERSION}/g; s/\@\@PAYLOAD_SHA256\@\@/$ENV{PSUM}/g' \
  install/installer-template.sh > "$RUN"
tail -n 1 "$RUN" | grep -qx '__PAYLOAD_BELOW__' || { echo "STOP: template must end with __PAYLOAD_BELOW__" >&2; exit 1; }
cat "$OUT/payload.tar.gz" >> "$RUN"
chmod 755 "$RUN"
rm -rf "$OUT/stage" "$OUT/payload.tar.gz"

( cd "$OUT" && sha "$(basename "$RUN")" ) | tee "releases/php56-hardened-$VERSION.run.sha256"
ls -lh "$RUN"

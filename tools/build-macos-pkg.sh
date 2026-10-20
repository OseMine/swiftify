#!/usr/bin/env bash
# builds a macos .pkg installer from an app bundle tools/build-macos-dmg.sh
# already built, bundled and signed
#
# usage
#   ./tools/build-macos-pkg.sh --app build-macos-dmg/Swiftify.app
#   ./tools/build-macos-pkg.sh --app build-macos-dmg/Swiftify.app --out dist
#
# the pkg installs into /Applications, which asks for an administrator
# password: it is for people and fleets that prefer installer's flow, while
# the dmg stays the drag-it-across build

set -euo pipefail

APP=""
OUT="dist"

while [[ $# -gt 0 ]]; do
    case $1 in
        --app) APP="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option $1" >&2; exit 1 ;;
    esac
done

fail() { echo "error, $1" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail "this builds macos packages only"
[[ -n "$APP" ]] || fail "pass --app with the path of a built Swiftify.app"
[[ -d "$APP/Contents/MacOS" ]] || fail "$APP is not an app bundle"
for tool in pkgbuild productbuild pkgutil ditto xattr; do
    command -v "$tool" >/dev/null || fail "$tool is missing, install xcode's command line tools"
done

SOURCE="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n '/^project(Swiftify/,/VERSION/s/^ *VERSION \([0-9.]*\).*/\1/p' "$SOURCE/CMakeLists.txt")"
[[ -n "$VERSION" ]] || fail "could not read the version from CMakeLists.txt"
NAME="swiftify-$VERSION-macos-arm64"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

WORK="$SOURCE/build-macos-pkg"
ROOT="$WORK/root"
COMPONENT="$WORK/component.pkg"
mkdir -p "$ROOT/Applications"
rm -rf "${ROOT:?}/Applications/Swiftify.app"
# ditto keeps the signature, the resource forks and the symlinks macdeployqt
# left in the frameworks
xattr -cr "$APP"
ditto "$APP" "$ROOT/Applications/Swiftify.app"

echo "app $APP"
echo "version $VERSION"
echo "output $OUT/$NAME.pkg"

rm -f "$COMPONENT" "$OUT/$NAME.pkg"
pkgbuild --root "$ROOT" \
    --identifier "dev.addenator.Swiftify.Qt" \
    --version "$VERSION" \
    --install-location / \
    --ownership recommended \
    "$COMPONENT"

# the payload has to hold the app and nothing else, and the bundle in it has
# to still verify: pkgbuild can flatten a symlinked framework. pkgutil prints
# the paths payload-relative on some systems and absolute on others
pkgutil --payload-files "$COMPONENT" | grep -Eq '(^|/)Applications/Swiftify\.app/Contents/MacOS/swiftify$' \
    || fail "the pkg does not carry the app"
codesign --verify --deep --strict "$ROOT/Applications/Swiftify.app" \
    || fail "the app in the pkg does not verify"

productbuild --package "$COMPONENT" "$OUT/$NAME.pkg"
[[ -s "$OUT/$NAME.pkg" ]] || fail "productbuild wrote no pkg"

echo "built $OUT/$NAME.pkg"

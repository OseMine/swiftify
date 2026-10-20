#!/usr/bin/env bash
# builds .deb, .rpm and .AppImage from the bundled tree that
# tools/build-linux-tarball.sh leaves in its AppDir
#
# usage
#   ./tools/build-linux-packages.sh --appdir build-linux-tarball/AppDir
#   ./tools/build-linux-packages.sh --appdir build-linux-tarball/AppDir --out dist
#   ./tools/build-linux-packages.sh --appdir ... --formats deb,appimage
#
# the appdir already holds qt, its plugins and swiftify's libraries, deployed
# by linuxdeploy. this adds the packaging around that same tree, so a deb, an
# rpm and the tarball all carry one build. needs dpkg-deb for the deb,
# rpmbuild for the rpm, and linuxdeploy for the AppImage

set -euo pipefail

APPDIR=""
OUT="dist"
FORMATS="deb,rpm,appimage"
LINUXDEPLOY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --appdir) APPDIR="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --formats) FORMATS="$2"; shift 2 ;;
        --linuxdeploy) LINUXDEPLOY="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option $1" >&2; exit 1 ;;
    esac
done

fail() { echo "error, $1" >&2; exit 1; }
wants() { [[ ",$FORMATS," == *",$1,"* ]]; }

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || fail "this packages linux x86_64 only"
[[ -n "$APPDIR" ]] || fail "pass --appdir with the AppDir tools/build-linux-tarball.sh leaves"
APPDIR="$(cd "$APPDIR" && pwd)"
[[ -x "$APPDIR/usr/bin/swiftify" ]] || fail "no usr/bin/swiftify in $APPDIR"

SOURCE="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n '/^project(Swiftify/,/VERSION/s/^ *VERSION \([0-9.]*\).*/\1/p' "$SOURCE/CMakeLists.txt")"
[[ -n "$VERSION" ]] || fail "could not read the version from CMakeLists.txt"
NAME="swiftify-$VERSION-linux-x86_64"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

WORK="$SOURCE/build-linux-packages"
mkdir -p "$WORK"

echo "appdir  $APPDIR"
echo "version $VERSION"
echo "formats $FORMATS"

# --- deb --------------------------------------------------------------------

if wants deb; then
    command -v dpkg-deb >/dev/null || fail "dpkg-deb is missing, it packages the deb"
    STAGE="$WORK/deb"
    rm -rf "${STAGE:?}"
    mkdir -p "$STAGE/DEBIAN"
    cp -a "$APPDIR/usr" "$STAGE/usr"
    INSTALLED_KB="$(du -sk "$STAGE/usr" | cut -f1)"
    # libasound and libssl were renamed with the time_t transition, so both
    # names are offered. the rest are the libraries the tarball leaves to the
    # system on purpose (see tools/build-linux-tarball.sh)
    cat > "$STAGE/DEBIAN/control" <<EOF
Package: swiftify
Version: $VERSION
Architecture: amd64
Maintainer: Swiftify <swiftify@users.noreply.github.com>
Installed-Size: $INSTALLED_KB
Section: sound
Priority: optional
Depends: libc6 (>= 2.35), libstdc++6, libgcc-s1, libasound2t64 | libasound2, libsecret-1-0,
 libpulse0, libglib2.0-0, libdbus-1-3, libxkbcommon0, libwayland-client0, libwayland-cursor0,
 libfontconfig1, libfreetype6, libssl3t64 | libssl3
Recommends: xdg-desktop-portal
Description: a native Spotify client
 Swiftify plays your Spotify library through librespot, with an immersive
 player, synced lyrics, visualizers, an equalizer, local files and local
 playlists. It follows Material 3 Expressive and stays lighter than the
 Spotify client it replaces.
EOF
    dpkg-deb --root-owner-group --build "$STAGE" "$OUT/$NAME.deb" >/dev/null
    dpkg-deb --info "$OUT/$NAME.deb" >/dev/null || fail "the deb does not read back"
    echo "built $OUT/$NAME.deb"
fi

# --- rpm --------------------------------------------------------------------

if wants rpm; then
    command -v rpmbuild >/dev/null || fail "rpmbuild is missing, it packages the rpm"
    RPMROOT="$WORK/rpmbuild"
    rm -rf "${RPMROOT:?}"
    mkdir -p "$RPMROOT"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
    # every path the appdir holds, so nothing is left unpackaged
    FILES="$WORK/rpm-files.list"
    ( cd "$APPDIR" && find usr -mindepth 1 | LC_ALL=C sort | sed 's|^|/|' ) > "$FILES"
    cat > "$RPMROOT/SPECS/swiftify.spec" <<EOF
%global debug_package %{nil}
%define _build_id_links none

Name:           swiftify
Version:        $VERSION
Release:        1
Summary:        A native Spotify client
License:        custom
URL:            https://github.com/shredos67/swiftify
BuildArch:      x86_64
AutoReqProv:    yes

%description
Swiftify plays your Spotify library through librespot, with an immersive
player, synced lyrics, visualizers, an equalizer, local files and local
playlists. It follows Material 3 Expressive and stays lighter than the
Spotify client it replaces.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a "$APPDIR/usr" %{buildroot}/usr

%files -f $FILES

%changelog
EOF
    rpmbuild --define "_topdir $RPMROOT" -bb "$RPMROOT/SPECS/swiftify.spec" >/dev/null
    built="$(find "$RPMROOT/RPMS" -name '*.rpm' -print -quit)"
    [[ -n "$built" ]] || fail "rpmbuild wrote no rpm"
    cp "$built" "$OUT/$NAME.rpm"
    rpm -qp --qf '%{NAME} %{VERSION}\n' "$OUT/$NAME.rpm" >/dev/null || fail "the rpm does not read back"
    echo "built $OUT/$NAME.rpm"
fi

# --- AppImage ---------------------------------------------------------------

if wants appimage; then
    if [[ -z "$LINUXDEPLOY" ]]; then
        LINUXDEPLOY="$SOURCE/build-linux-tarball/tools/linuxdeploy-x86_64.AppImage"
    fi
    [[ -x "$LINUXDEPLOY" ]] || fail "no linuxdeploy at $LINUXDEPLOY; build the tarball first or pass --linuxdeploy"
    mkdir -p "$WORK/appimage"
    rm -f "$WORK/appimage"/*.AppImage
    # the appdir is already deployed, so this only packs it
    ( cd "$WORK/appimage" && \
      APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$LINUXDEPLOY" \
        --appdir "$APPDIR" --executable "$APPDIR/usr/bin/swiftify" --output appimage >/dev/null )
    built="$(find "$WORK/appimage" -maxdepth 1 -name '*.AppImage' -print -quit)"
    [[ -n "$built" ]] || fail "linuxdeploy wrote no AppImage"
    cp "$built" "$OUT/$NAME.AppImage"
    chmod +x "$OUT/$NAME.AppImage"
    echo "built $OUT/$NAME.AppImage"
fi

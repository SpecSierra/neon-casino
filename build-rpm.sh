#!/bin/sh
# Build the noarch RPM into dist/. QML-only app: no compiler or SDK needed, just rpmbuild.
set -e
cd "$(dirname "$0")"
NAME=harbour-neoncasino
VER=$(sed -n 's/^Version: *//p' rpm/$NAME.spec)
# the About page reads the version from here (generated, git-tracked, kept in step with the spec)
printf '.pragma library\n// Written by build-rpm.sh from the spec. Do not edit.\nvar version = "%s"\n' "$VER" > qml/js/Version.js
git add qml/js/Version.js 2>/dev/null || true
TOP=$(mktemp -d)
mkdir -p "$TOP/SOURCES" dist
git ls-files -z qml icons $NAME.desktop | tar --null -T - --transform "s,^,$NAME-$VER/," -czf "$TOP/SOURCES/$NAME-$VER.tar.gz"
rpmbuild -bb --define "_topdir $TOP" --define "_datadir /usr/share" \
    --define "_binary_payload w9.xzdio" --define "_build_id_links none" rpm/$NAME.spec
cp "$TOP"/RPMS/noarch/*.rpm dist/
rm -rf "$TOP"
ls dist/

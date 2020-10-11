#!/bin/sh

# Copyright (C) 2020 by Michael Graves
#
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
# OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

REL="edge"
MIRROR="http://dl-cdn.alpinelinux.org/alpine"
MAINREPO="$MIRROR/$REL/main"
ADDITIONALREPO="$MIRROR/$REL/community"
ARCH=${ARCH:-$(uname -m)}
BUILD="./build"

if [ -d $BUILD ]; then
	# cleanup after old build
	rm -rf $build
fi
mkdir -p $BUILD

# figure out what version we will use
apkv=$(curl -sSL $MAINREPO/$ARCH/APKINDEX.tar.gz | tar -Oxz | grep --text '^P:apk-tools-static$' -A1 | tail -n1 | cut -d: -f2 )

# setup temproary directory
echo -n "Setting up temporary directories..."
TMP=$(mktemp -d $BUILD/docker-alpine-XXXXXXXXXX)
ROOTFS=$(mktemp -d $BUILD/docker-alpine-root-XXXXXXXXXX)
trap "rm -rf $TMP $ROOTFS $BUILD" EXIT TERM INT
echo "Done"

# fetch the apk tools
echo -n "Fetching apk-tools..."
curl -sSL $MAINREPO/$ARCH/apk-tools-static-${apkv}.apk -O
if [ $? -ne 0 ]; then
	echo "failed getting apk-tools"
	exit
fi
# unpack apk
tar -f apk-tools-static-${apkv}.apk -xz -C $TMP sbin/apk.static
echo "Done"

echo -n "Making the base directory..."
$TMP/sbin/apk.static --repository $MAINREPO --no-cache --allow-untrusted --root $ROOTFS --initdb add alpine-base
echo "Done"

echo -n "Configuring base image..."
printf '%s\n' $MAINREPO > $ROOTFS/etc/apk/repositories
printf '%s\n' $ADDITIONALREPO >> $ROOTFS/etc/apk/repositories
echo "Done"

echo -n "Packaging image..."
id=$(tar --numeric-owner -C $ROOTFS -c . | docker import - alpine:$REL)
echo "Done"
echo -n "Testing package..."
docker run --rm alpine:${REL} printf 'Success! alpine:%s with id=%s created!\n' $REL $id
echo "Done"


#!/usr/bin/bash

source PKGBUILD

depends=(
    # gcc
    'gcc'

    # strip
    'binutils'

    # bsdtar
    'libarchive-tools'

    'flatpak-xdg-utils'
)

for depend in "${depends[@]}"; do
    sudo apt install $depend
done

CARCH=$(uname -m)
echo "Your OS Arch is $CARCH"

source=source_$CARCH
source=${!source}
echo "Your soure is: $source"

package_name="${source%%::*}"
package_url="${source#*::}"

echo "Package name: $package_name"
echo "Package download url: $package_url"

curl -L $package_url -o $package_name

pkgdir='pkgdir'
mkdir -p $pkgdir

build

package

sudo cp -Rv --no-preserve=mode,ownership pkgdir/* /

rm $package_name
rm -rf $pkgdir
rm ${_lib_uos}.so
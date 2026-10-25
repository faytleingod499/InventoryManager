#!/bin/bash
# Makes the zip from package/ (rebuild package/InventoryManager/InventoryManager.pck first with pack.gd, see the README):
#   out/InventoryManager-<version>.zip   the Thunderstore upload
set -e
cd "$(dirname "$0")"
mkdir -p out
V=$(python3 -c "import json;print(json.load(open('thunderstore/manifest.json'))['version_number'])")
rm -f out/InventoryManager-mod.zip out/InventoryManager-$V.zip
(cd package && zip -qr ../out/InventoryManager-mod.zip InventoryManager)
T=$(mktemp -d)
cp thunderstore/manifest.json thunderstore/README.md thunderstore/CHANGELOG.md thunderstore/icon.png $T/
cp LICENSE $T/
mkdir -p $T/GDWeave/mods/InventoryManager
cp package/InventoryManager/manifest.json package/InventoryManager/InventoryManager.pck $T/GDWeave/mods/InventoryManager/
(cd $T && zip -qr - .) > out/InventoryManager-$V.zip
rm -rf $T
echo "out/InventoryManager-mod.zip"
echo "out/InventoryManager-$V.zip"

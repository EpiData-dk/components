#!/bin/sh
set -e

if ! [ ${OSTYPE:0:6} = "darwin" ]; then
  echo " Skipping post-compile script -- for Mac only"
  exit
fi

cp -p Info.plist PasMap.app/Contents
cp -p PasMap.icns PasMap.app/Contents/Resources
rm PasMap.app/Contents/MacOS/PasMap
cp -p PasMap PasMap.app/Contents/MacOS

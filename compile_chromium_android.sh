#!/bin/bash
set -e && cd

#
# example of use:
# root@jarvis:~# ./compile_chromium_android.sh --lkgr
#

# parameters
while [[ "$#" > 0 ]];
    do
        PARAM=$(echo ${1,,})
        case $PARAM in
        --lkgr)
            FLAG_LKGR=y
            ;;
        --x86)
            FLAG_ARCH_x86=y
            ;;
        --mips)
            FLAG_ARCH_MIPS=y
            ;;
        *)
            echo -e "Unknown argument $1"
	    exit
            ;;
        esac
        shift
done

# directories
CHROMIUM_DIR="$HOME/chromium"
CHROMIUM_OUT_DIR="$HOME/chromium_builds"
DEPOT_TOOLS_DIR="$HOME/depot_tools"

# colors
GRN='\033[0;32m'
NRML='\033[0m'

# add some sources (for msttcorefonts)
sudo echo 'deb http://us.archive.ubuntu.com/ubuntu/ trusty multiverse' >> /etc/apt/sources.list
sudo echo 'deb-src http://us.archive.ubuntu.com/ubuntu/ trusty multiverse' >> /etc/apt/sources.list
sudo echo 'deb http://us.archive.ubuntu.com/ubuntu/ trusty-updates multiverse' >> /etc/apt/sources.list
sudo echo 'deb-src http://us.archive.ubuntu.com/ubuntu/ trusty-updates multiverse' >> /etc/apt/sources.list
sudo apt-get update -y
sudo apt-get upgrade -y

# install necessary packages
sudo apt-get install openjdk-7-jdk git -y

# install depot_tools
if [ -d $DEPOT_TOOLS_DIR ]; then
  rm -rf $DEPOT_TOOLS_DIR
fi
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $DEPOT_TOOLS_DIR
export PATH=$PATH:$DEPOT_TOOLS_DIR

# clone the chromium source code
if [ -d $CHROMIUM_DIR ]; then
  rm -rf $CHROMIUM_DIR
fi
mkdir $CHROMIUM_DIR
cd $CHROMIUM_DIR
fetch --nohooks android

# last known good revision
CHROMIUM_LKGR="$(curl http://chromium-status.appspot.com/lkgr)"

# check out LKGR
if [ "$FLAG_LKGR" = 'y' ]; then
  gclient sync --nohooks -r $CHROMIUM_LKGR
fi

# configure GYP
if [ "$FLAG_ARCH_x86" = 'y' ] || [ "$FLAG_ARCH_MIPS" = 'y' ]; then
  if [ "$FLAG_ARCH_x86" = 'y' ]; then
    echo "{ 'GYP_DEFINES': 'OS=android target_arch=ia32', }" > chromium.gyp_env
  fi
  if [ "$FLAG_ARCH_MIPS" = 'y' ]; then
    echo "{ 'GYP_DEFINES': 'OS=android target_arch=mipsel', }" > chromium.gyp_env
  fi
else
  echo "{ 'GYP_DEFINES': 'OS=android', }" > chromium.gyp_env
fi

# clear GYP_DEFINES environment variable
unset GYP_DEFINES

# install build dependencies
$CHROMIUM_DIR/src/build/install-build-deps.sh
$CHROMIUM_DIR/src/build/install-build-deps-android.sh

# android SDK
$CHROMIUM_DIR/src/third_party/android_tools/sdk/tools/android update sdk --no-ui --filter 57
gclient runhooks

# add aapt to PATH
export PATH=$PATH:$CHROMIUM_DIR/src/third_party/android_tools/sdk/build-tools/*/

# date
DATE="$(date -u +%Y%m%d)"

# build the full browser
cd $CHROMIUM_DIR/src
ninja -C out/Release chrome_public_apk

# chromium version
CHROMIUM_VER_FILE="$CHROMIUM_DIR/src/chrome/VERSION"
VER_MAJOR="$(cat $CHROMIUM_VER_FILE | grep 'MAJOR=' | sed 's/MAJOR=//')"
VER_MINOR="$(cat $CHROMIUM_VER_FILE | grep 'MINOR=' | sed 's/MINOR=//')"
VER_BUILD="$(cat $CHROMIUM_VER_FILE | grep 'BUILD=' | sed 's/BUILD=//')"
VER_PATCH="$(cat $CHROMIUM_VER_FILE | grep 'PATCH=' | sed 's/PATCH=//')"
CHROMIUM_VER="$(echo $VER_MAJOR.$VER_MINOR.$VER_BUILD.$VER_PATCH)"

# short hash of the latest commit
LATEST_COMMIT="$(cd $CHROMIUM_DIR/src && git rev-parse --short HEAD && cd ../..)"

# chromium apk filename
CHROMIUM_APK_FILENAME="chromium-$CHROMIUM_VER-$DATE-$LATEST_COMMIT.apk"

# grab the chromium apk
cd
if [ ! -d $CHROMIUM_OUT_DIR ]; then
  mkdir $CHROMIUM_OUT_DIR
fi
CHROMIUM_OUT_APK=$CHROMIUM_OUT_DIR/$CHROMIUM_APK_FILENAME
cp $CHROMIUM_DIR/src/out/Release/apks/ChromePublic.apk $CHROMIUM_OUT_APK

# let the party begin
echo && echo -e "${GRN}APK:${NRML} $CHROMIUM_OUT_APK" && echo

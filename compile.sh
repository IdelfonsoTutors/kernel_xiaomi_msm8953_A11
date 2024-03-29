#!/bin/sh

# Copyright (C) 2020 Lacia chan / Lyceris chan <ghostdrain@outlook.com>
# Copyright (C) 2018 Harsh 'MSF Jarvis' Shandilya
# Copyright (C) 2018 Akhil Narang
# SPDX-License-Identifier: GPL-3.0-only

# If this script is ran by anyone else then Lacia it will simply only setup the compile environment without setting up any telegram / incremental stuff.

# Setup the build environment
git clone --depth=1 https://github.com/akhilnarang/scripts environment
cd environment && bash setup/android_build_env.sh && cd ..

# Clone proton clang from kdrag0n's repo
git clone --depth=1 https://github.com/kdrag0n/proton-clang proton-clang

# Clone AnyKernel3
git clone --depth=1 https://github.com/Couchpotato-sauce/AnyKernel3 AnyKernel3

# Setup everything used for incremental releases (Lacia only)
incremental() {
    FILE="incremental/value.dat"
    if [ -f "$FILE" ]; then
        # Read the value from the file
        value=$(cat incremental/value.dat)

        # increment the value
        value=$((value + 1))

        # and save it for next time
        echo "${value}" >incremental/value.dat

        # push to git
        cd incremental || exit
        git add .
        git commit -m +1
        git push
        cd ..

    else

        git clone https://github.com/Lyceris-chan/incremental_release incremental

        # Read the value from the file
        value=$(cat incremental/value.dat)

        # increment the value
        value=$((value + 1))

        # and save it for next time
        echo "${value}" >incremental/value.dat

        # push to git
        cd incremental || exit
        git add .
        git commit -m +1
        git push
        cd ..
    fi
}

if [ "$(whoami)" = "gitpod" ]  || [ "$(whoami)" = "lacia-chan" ] || [ "$(whoami)" = "レイシア" ]; then
    incremental
else
    sleep 10
fi

# Fetch latest wireguard version if ran by Lacia
wireguard() {
    ./scripts/fetch-latest-wireguard.sh
}

if [ "$(whoami)" = "gitpod" ]  || [ "$(whoami)" = "lacia-chan" ] || [ "$(whoami)" = "レイシア" ]; then
    wireguard
else
    sleep 10
fi

# Export and set some variables that will be used later
CORES=$(grep -c ^processor /proc/cpuinfo)
BUILD_START=$(date +"%s")
DATE=$(date)
PARSE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT_POINT="$(git log --pretty=format:'%h : %s' -1)"
PATH="$(pwd)/proton-clang/bin:$PATH"
KBUILD_COMPILER_STRING="$($(pwd)/proton-clang/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
RELEASE=$(cat incremental/value.dat)

export PATH
export KBUILD_COMPILER_STRING

# Git log the last 10 commits and upload them to del.dog (Lacia only)
if [ "$(whoami)" = "gitpod" ]  || [ "$(whoami)" = "lacia-chan" ] || [ "$(whoami)" = "レイシア" ]; then
    git log --pretty=oneline -10 >changelog.txt
    CHANGELOG=$(cat changelog.txt | curl -F 'sprunge=<-' http://sprunge.us)
    echo $CHANGELOG
else
    sleep 10
fi

# Setup Telegram API stuff (Lacia only)
TelegramAPI() {
    FILE="$(pwd)/bapi/bottoken.txt"
    if [ -f "$FILE" ]; then
        # Export the BOTTOKEN and CHATID from my private repository
        BOTTOKEN="$(sed 's/BOTTOKEN = //g' "$(pwd)"/bapi/bottoken.txt)"
        CHATID="$(sed 's/CHATID = //g' "$(pwd)"/bapi/chatid.txt)"
    else
        # Clone my private repository for the CHATID and BOTTOKEN
        git clone https://github.com/Lyceris-chan/telegram_bot_api_stuff bapi
        # Export the BOTTOKEN and CHATID from my private repository
        BOTTOKEN="$(sed 's/BOTTOKEN = //g' "$(pwd)"/bapi/bottoken.txt)"
        CHATID="$(sed 's/CHATID = //g' "$(pwd)"/bapi/chatid.txt)"
    fi
}

if [ "$(whoami)" = "gitpod" ]  || [ "$(whoami)" = "lacia-chan" ] || [ "$(whoami)" = "レイシア" ]; then
    TelegramAPI
else
    sleep 10
fi

# Figure out the localversion
rm -rf localv.txt
grep "SUBLEVEL =" Makefile >localv.txt
SUBLVL="$(sed 's/SUBLEVEL = //g' localv.txt)"
LOCALV=4.9.$SUBLVL

# Clean up out
rm -rf out/*

# Post build compilation information in $CHATID
TelegramInfo() {
    curl -s -X POST "https://api.telegram.org/bot$BOTTOKEN/sendMessage" -d chat_id="-$CHATID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="
⚙️Build for \`Daisy / Sakura (non SAR)\` started at \`$DATE\` using \`$CORES\` threads.

Compiler: \`$KBUILD_COMPILER_STRING\`
Localversion: \`$LOCALV\`

Release: \`r$RELEASE\`

Branch: \`$PARSE_BRANCH\`
Commit: \`$COMMIT_POINT\`

Changelog [Here!]($CHANGELOG)

Kernel: \`sleepy ~ but my college is a serious joke!\`"
}

if [ "$(whoami)" = "gitpod" ]  || [ "$(whoami)" = "lacia-chan" ] || [ "$(whoami)" = "レイシア" ]; then
    TelegramInfo
else
    sleep 10
fi

# Compile the kernel
build_clang() {
    make -j"$(nproc --all)" \
	O=out \
	ARCH=arm64 \
    CC="ccache clang" \
    CXX="ccache clang++" \
    AR="ccache llvm-ar" \
    AS="ccache llvm-as" \
    NM="ccache llvm-nm" \
    LD="ccache ld.lld" \
    STRIP="ccache llvm-strip" \
    OBJCOPY="ccache llvm-objcopy" \
    OBJDUMP="ccache llvm-objdump"\
    OBJSIZE="ccache llvm-size" \
    READELF="ccache llvm-readelf" \
    HOSTCC="ccache clang" \
    HOSTCXX="ccache clang++" \
    HOSTAR="ccache llvm-ar" \
    HOSTAS="ccache llvm-as" \
    HOSTNM="ccache llvm-nm" \
    HOSTLD="ccache ld.lld" \
	CROSS_COMPILE=aarch64-linux-gnu- \
	CROSS_COMPILE_ARM32=arm-linux-gnueabi-
}

make O=out ARCH=arm64 sleepy_defconfig
build_clang

# Calculate how long compiling compiling the kernel took
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

# Post the releasing in $CHATID
TelegramSuccess() {
    curl -F document=@"$(pwd)/AnyKernel3/Sleepy-r${RELEASE}-${BUILD_TIME}.zip" "https://api.telegram.org/bot$BOTTOKEN/sendDocument" \
        -F chat_id="-$CHATID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=Markdown" \
        -F caption="✅ Build finished in \`$(($DIFF / 60))\` minute(s) and \`$(($DIFF % 60))\` seconds
        MD5SUM: $MD5
        SHASUM: $SHA"
}

# Notify $CHATID about the fact that the build failed
TelegramFailure() {
    curl -s -X POST "https://api.telegram.org/bot$BOTTOKEN/sendMessage" -d chat_id="-$CHATID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Build failed in \`$(($DIFF / 60))\` minute(s) and \`$(($DIFF % 60))\` seconds check you're terminal"
}

# Zip up the kernel
zip_kernelimage() {
    rm -rf "$(pwd)"/AnyKernel3/Image.gz-dtb
    cp "$(pwd)"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3
    rm -rf "$(pwd)"/AnyKernel3/*.zip
    BUILD_TIME=$(date +"%d%m%Y-%H%M")
    cd AnyKernel3 || exit
    if [ ! -f "incremental/value.dat" ]; then
        KERNEL_NAME=Sleepy-"${BUILD_TIME}"
    else 
        KERNEL_NAME=Sleepy-r"${RELEASE}"-"${BUILD_TIME}"
    fi
    zip -r9 "$KERNEL_NAME".zip ./*
    cd ..
}

# Get MD5SUM and SHASUM of the zipped kernel
Hash() {
    SHA=$(shasum "$(pwd)"/AnyKernel3/Sleepy-r"${RELEASE}"-"${BUILD_TIME}".zip | cut -f 1 -d '/')
    MD5=$(md5sum "$(pwd)"/AnyKernel3/Sleepy-r"${RELEASE}"-"${BUILD_TIME}".zip | cut -f 1 -d '/')
}

# If the kernel compiled sucessfully zip it up and upload to $CHATID (Lacia only), otherwise just zip it up and print the location of the zip.
TelegramStatus() {
    # Check if compilation went successfully
    FILE="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"
    if [ -f "$FILE" ]; then
        zip_kernelimage
        Hash
        TelegramSuccess
    else
        TelegramFailure
    fi
}

if [ "$(whoami)" = "gitpod" ]  || [ "$(whoami)" = "lacia-chan" ] || [ "$(whoami)" = "レイシア" ]; then
    TelegramStatus
else
    FILE="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"
    if [ -f "$FILE" ]; then
        zip_kernelimage
        echo "The kernel has successfully been compiled and can be found in $(pwd)/AnyKernel3/"$KERNEL_NAME".zip"
        FILE_CI="/drone/src/AnyKernel3/"$KERNEL_NAME".zip"
        if [ -f "$FILE_CI" ]; then
            curl --connect-timeout 10 -T "$FILE_CI" https://oshi.at
            curl --connect-timeout 10 --upload-file "$FILE_CI" https://transfer.sh
            echo " "
        elif [ ! -f "$FILE_CI" ] && [ $(whoami) = "node" ]; then
            exit 1
        fi
    fi
fi

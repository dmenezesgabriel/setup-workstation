#!/bin/bash

start_time=$(date +%s)

NERD_FONTS_PATH=~/NerdFonts

echo "Create NerdFonts directory"

rm -rf $NERD_FONTS_PATH
mkdir -p $NERD_FONTS_PATH

echo "Change directory to NerdFonts"

cd $NERD_FONTS_PATH

echo "Download FiraCode font"

wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip

echo "Unzip FiraCode"

unzip FiraCode.zip

cp FiraCode<font>.ttf ~/termux/font.ttf

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
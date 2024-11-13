#!/bin/sh

JETBRAINS_MONO_RELEASE_URL="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
SYSTEM_FONTS_PATH=~/.fonts
ASSERTS_DIR=~/Documents/assets/
FONTS_DIR="$ASSERTS_DIR"/fonts

mkdir -p "$FONTS_DIR" && \
curl -L -o "$FONTS_DIR"/jetbrains-mono.zip "$JETBRAINS_MONO_RELEASE_URL" && \
unzip "$FONTS_DIR"/jetbrains-mono.zip -d "$FONTS_DIR"/jetbrains-mono && \
mv "$FONTS_DIR"/jetbrains-mono/fonts/ttf/* "$SYSTEM_FONTS_PATH" && \
fc-cache -f -v

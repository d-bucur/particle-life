#!/bin/bash -eu

# MAYBE build scripts are a bit of a mess. Use just instead and update vscode tasks
OUT_DIR="build/desktop"
mkdir -p $OUT_DIR
odin build source/main_desktop -o:speed -out:$OUT_DIR/game_desktop.bin
cp -R ./assets/ ./$OUT_DIR/assets/
echo "Desktop build created in ${OUT_DIR}"
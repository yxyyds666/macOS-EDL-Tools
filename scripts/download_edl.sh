#!/bin/bash

# EDL Tool Download Script
# Downloads the EDL Python library for embedding

EDL_DIR="$(dirname "$0")/../Resources/edl"
EDL_REPO="https://github.com/bkerler/edl.git"

echo "Downloading EDL tools..."

if [ -d "$EDL_DIR" ]; then
    echo "EDL directory already exists. Updating..."
    cd "$EDL_DIR" && git pull
else
    echo "Cloning EDL repository..."
    git clone --depth 1 "$EDL_REPO" "$EDL_DIR"
    # Remove git directory to avoid submodule issues
    rm -rf "$EDL_DIR/.git"
    rm -rf "$EDL_DIR/.github"
fi

echo "EDL tools downloaded to: $EDL_DIR"
echo ""
echo "Note: Make sure you have Python 3 and required dependencies installed:"
echo "  pip3 install -r $EDL_DIR/requirements.txt"

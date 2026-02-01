#!/bin/bash
set -e

PLUGIN_DIR=$(cd "$(dirname "$0")/.." && pwd)
VENV_DIR="$PLUGIN_DIR/.venv"

echo "Tungsten: Setting up Python virtual environment..."

if [ ! -f "$VENV_DIR/bin/python" ] && [ ! -f "$VENV_DIR/Scripts/python.exe" ]; then
    if [ -d "$VENV_DIR" ]; then
        echo "Tungsten: Found broken/empty .venv directory. Recreating..."
        rm -rf "$VENV_DIR"
    fi
    
    echo "Tungsten: Creating new venv at $VENV_DIR..."
    if command -v python3 &> /dev/null; then
        python3 -m venv "$VENV_DIR"
    elif command -v python &> /dev/null; then
        python -m venv "$VENV_DIR"
    else
        echo "Error: Neither 'python3' nor 'python' found in PATH."
        exit 1
    fi
fi

if [ -f "$VENV_DIR/bin/python" ]; then
    PYTHON_EXEC="$VENV_DIR/bin/python"
elif [ -f "$VENV_DIR/Scripts/python.exe" ]; then
    PYTHON_EXEC="$VENV_DIR/Scripts/python.exe"
else
    echo "Error: Failed to create python executable in $VENV_DIR"
    exit 1
fi

echo "Tungsten: Installing dependencies..."
"$PYTHON_EXEC" -m pip install --upgrade pip
"$PYTHON_EXEC" -m pip install -r "$PLUGIN_DIR/requirements.txt"

echo "Tungsten: Python setup complete."

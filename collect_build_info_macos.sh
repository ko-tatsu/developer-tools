#!/bin/bash

set -u

# ============================================================
# Generic macOS Build / Development Environment Collector
#
# Usage:
#   collect_build_info_macos.sh
#   collect_build_info_macos.sh <output-directory>
#
# The current working directory is treated as the project root.
# This script only reads information. It does not modify the
# project, Git repository, Python environment, or Conda environment.
# ============================================================

PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

OUTPUT_DIR="${1:-$PROJECT_DIR}"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
OUTPUT_FILE="${OUTPUT_DIR}/build_info_${PROJECT_NAME}_macOS_${TIMESTAMP}.md"

mkdir -p "$OUTPUT_DIR"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

{
    echo "# Build / Development Environment Information"
    echo
    echo "## Project"
    echo
    echo "- Project: \`$PROJECT_NAME\`"
    echo "- Project directory: \`$PROJECT_DIR\`"
    echo "- Collected: \`$(date '+%Y-%m-%d %H:%M:%S %Z')\`"
    echo

    echo "## Operating system"
    echo
    if command_exists sw_vers; then
        echo '```text'
        sw_vers
        echo "Architecture: $(uname -m)"
        echo '```'
    else
        echo "macOS information unavailable."
    fi
    echo

    echo "## Hardware"
    echo
    echo '```text'
    if command_exists system_profiler; then
        system_profiler SPHardwareDataType 2>/dev/null \
            | grep -E "Model Name|Model Identifier|Chip|Processor|Memory" \
            || echo "Hardware information unavailable."
    else
        echo "system_profiler unavailable."
    fi
    echo '```'
    echo

    echo "## Git"
    echo
    if command_exists git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "- Repository root: \`$(git rev-parse --show-toplevel)\`"
        echo "- Branch: \`$(git branch --show-current)\`"
        echo "- Commit: \`$(git rev-parse HEAD)\`"
        echo "- Short commit: \`$(git rev-parse --short HEAD)\`"
	echo "- Commit date: \`$(git show -s --format='%cI' HEAD 2>/dev/null || echo 'Unavailable')\`"

        TAG="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
        if [ -n "$TAG" ]; then
            echo "- Exact tag: \`$TAG\`"
        else
            echo "- Exact tag: \`None\`"
        fi

        DESCRIBE="$(git describe --tags --always --dirty 2>/dev/null || true)"
        if [ -n "$DESCRIBE" ]; then
            echo "- Nearest Git description: \`$DESCRIBE\`"
        fi

        if [ -z "$(git status --porcelain)" ]; then
            echo "- Working tree: \`Clean\`"
        else
            echo "- Working tree: \`Modified / untracked files present\`"
        fi

        REMOTE="$(git remote get-url origin 2>/dev/null || true)"
        if [ -n "$REMOTE" ]; then
            echo "- Origin: \`$REMOTE\`"
        fi
    else
        echo "Not inside a Git repository."
    fi
    echo

    echo "## Python"
    echo
    if command_exists python; then
        echo "- Version: \`$(python --version 2>&1)\`"
        echo "- Executable: \`$(command -v python)\`"
    elif command_exists python3; then
        echo "- Version: \`$(python3 --version 2>&1)\`"
        echo "- Executable: \`$(command -v python3)\`"
    else
        echo "Python not found."
    fi
    echo

    echo "## Conda"
    echo
    if command_exists conda; then
        echo "- Active environment: \`${CONDA_DEFAULT_ENV:-None}\`"
        echo "- Conda executable: \`$(command -v conda)\`"
        echo "- Conda version: \`$(conda --version 2>&1)\`"
    else
        echo "Conda not found."
    fi
    echo

    echo "## PyInstaller"
    echo
    if command_exists python && python -m PyInstaller --version >/dev/null 2>&1; then
        echo "- Version: \`$(python -m PyInstaller --version 2>&1)\`"
    elif command_exists pyinstaller; then
        echo "- Version: \`$(pyinstaller --version 2>&1)\`"
    else
        echo "PyInstaller not found in the active environment."
    fi
    echo

    echo "## Environment / dependency files"
    echo
    FOUND_ENV_FILE=0

    for FILE in \
        requirements.txt \
        requirements-build.txt \
        environment.yml \
        environment.yaml \
        pyproject.toml \
        setup.py \
        setup.cfg \
        Pipfile \
        poetry.lock \
        uv.lock \
        Dockerfile \
        docker-compose.yml \
        compose.yml
    do
        if [ -f "$FILE" ]; then
            echo "- \`$FILE\`"
            FOUND_ENV_FILE=1
        fi
    done

    if [ "$FOUND_ENV_FILE" -eq 0 ]; then
        echo "No common environment/dependency files detected."
    fi
    echo

    echo "## PyInstaller specification files"
    echo
    shopt -s nullglob
    SPEC_FILES=(*.spec)

    if [ ${#SPEC_FILES[@]} -gt 0 ]; then
        for FILE in "${SPEC_FILES[@]}"; do
            echo "- \`$FILE\`"
        done
    else
        echo "No PyInstaller .spec files detected."
    fi
    shopt -u nullglob
    echo

    echo "## Release artifacts"
    echo

    FOUND_ARTIFACT=0

    for DIR in release dist; do
        if [ -d "$DIR" ]; then
            while IFS= read -r -d '' FILE; do
                FOUND_ARTIFACT=1
                NAME="$(basename "$FILE")"
                SIZE="$(du -h "$FILE" 2>/dev/null | awk '{print $1}')"
                SHA="$(shasum -a 256 "$FILE" 2>/dev/null | awk '{print $1}')"

                echo "### \`$NAME\`"
                echo
                echo "- Path: \`$FILE\`"
                echo "- Size: \`${SIZE:-Unavailable}\`"
                echo "- SHA-256: \`${SHA:-Unavailable}\`"
                echo
            done < <(
                find "$DIR" -maxdepth 1 -type f \
                    \( -name '*.zip' -o -name '*.tar.gz' -o -name '*.dmg' \) \
                    -print0 2>/dev/null
            )
        fi
    done

    if [ "$FOUND_ARTIFACT" -eq 0 ]; then
        echo "No common release archives detected in \`release/\` or \`dist/\`."
    fi
    echo

    echo "## Collector"
    echo
    echo "- Script: \`collect_build_info_macos.sh\`"
    echo "- This script only collected information and did not modify the development environment."
    echo

} > "$OUTPUT_FILE"

echo
echo "Build information collected successfully."
echo "Project: $PROJECT_NAME"
echo "Output: $OUTPUT_FILE"

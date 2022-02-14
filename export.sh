#!/bin/bash

source ".env"

readonly BUILDS_DIR="$ENV_PROJECT_DIR/$ENV_BUILDS_DIR"
readonly EXPORT_PRESETS="$ENV_PROJECT_DIR/export_presets.cfg"
readonly EXPORT_TEMPLATE="$ENV_PROJECT_DIR/$ENV_EXPORT_TEMPLATES_DIR/$ENV_EXPORT_TEMPLATE_FILE"
readonly TMP_DIR="$BUILDS_DIR/tmp"
readonly PROJECT_FILE="$ENV_PROJECT_DIR/project.godot"

PROJECT_NAME=""
PROJECT_VERSION=""
FILE_NAME=""
EXPORT_PLATFORMS=()
EXPORT_PATHS=()

function ctrl_c() {
  echo >&2
  echo "Cancelled by the user!" >&2
  echo >&2

  if [[ -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi

  exit 1
}

trap ctrl_c TERM INT

while IFS='=' read -r key value ; do
  if [[ "$key" == "config/name" ]]; then
    PROJECT_NAME="${value//\"/}"
  fi
  if [[ "$key" == "config/version" ]]; then
    PROJECT_VERSION="${value//\"/}"
  fi
done < "$PROJECT_FILE"

if [[ -z "$PROJECT_VERSION" ]]; then
  PROJECT_VERSION="1.0.0"
fi

mkdir -p "$BUILDS_DIR/$PROJECT_VERSION"

PROJECT_NAME="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
PROJECT_NAME="${PROJECT_NAME// /_}"
PROJECT_NAME="${PROJECT_NAME//-/_}"

FILE_NAME="${PROJECT_NAME}_${PROJECT_VERSION}"

while IFS='=' read -r key value ; do
  if [[ "$key" == "name" ]]; then
    EXPORT_PLATFORMS+=("$value")
  fi
  if [[ "$key" == "export_path" ]]; then
    EXPORT_PATHS+=("${value//\"/}")
  fi
done < "$EXPORT_PRESETS"

for i in "${!EXPORT_PLATFORMS[@]}"; do
  mkdir -p "$TMP_DIR"

  platform="${EXPORT_PLATFORMS[i]}"

  if [[ "$platform" == *"Windows"* ]]; then
    platform_name="windows"
    extension="exe"
  fi
  if [[ "$platform" == *"Mac OSX"* ]]; then
    platform_name="macos"
    extension="zip"
  fi
  if [[ "$platform" == *"Linux"* ]]; then
    platform_name="linux"
    extension="x86"
  fi
  if [[ "$platform" == *"Raspberry"* ]]; then
    platform_name="raspberry_pi"
    extension="rpi"
  fi

  if [[ "$platform" == *"32 bits"* ]]; then
    platform_name+="_32"
  fi
  if [[ "$platform" == *"64 bits"* ]]; then
    if [[ "$platform_name" == "linux" ]]; then
      extension+="_64"
    fi

    platform_name+="_64"
  fi

  echo
  echo "> Exporting $platform..."

  eval "$EXPORT_TEMPLATE" --quiet --export "$platform" "${TMP_DIR}/${FILE_NAME}.${extension}"

  if [[ "$?" -eq 0 ]]; then
    echo "$platform exported successfully!"
    sleep 0.5


    echo "> Generating \"${FILE_NAME}_${platform_name}.zip\"..."
    zip -q -r -j "${BUILDS_DIR}/${PROJECT_VERSION}/${FILE_NAME}_${platform_name}.zip" "$TMP_DIR"

    if [[ "$?" -eq 0 ]]; then
      echo "Done!"
      sleep 0.5
    else
      echo "ERROR: Couldn't zip $platform." >&2
      echo >&2
    fi

  else
    echo "ERROR: Couldn't export $platform." >&2
    echo >&2
  fi
  
  rm -rf "$TMP_DIR"

done

echo
echo "Finished!"

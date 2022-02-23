#!/bin/bash

source ".env"

shopt -s nocasematch

readonly PROJECT_DIR="$ENV_PROJECT_DIR"
readonly BUILDS_DIR="$PROJECT_DIR/$ENV_BUILDS_DIR"
readonly EXPORT_BINARIES_DIR="$PROJECT_DIR/$ENV_EXPORT_BINARIES_DIR"
readonly TMP_DIR="$BUILDS_DIR/tmp"

readonly PROJECT_FILE="$PROJECT_DIR/project.godot"
readonly EXPORT_PRESETS_FILE="$PROJECT_DIR/export_presets.cfg"
readonly EXPORT_PRESETS_TEMPLATE_FILE="$PROJECT_DIR/export_presets_template.cfg"

readonly GODOT_HEADLESS_BINARY="$EXPORT_BINARIES_DIR/$ENV_GODOT_HEADLESS_BINARY"
readonly RPI_32_EXPORT_TEMPLATE_BINARY="$EXPORT_BINARIES_DIR/$ENV_RPI_32_EXPORT_TEMPLATE_BINARY"
readonly RPI_64_EXPORT_TEMPLATE_BINARY="$EXPORT_BINARIES_DIR/$ENV_RPI_64_EXPORT_TEMPLATE_BINARY"

readonly GODOT_TEMPLATES_VERSION="$ENV_GODOT_TEMPLATES_VERSION"
readonly GODOT_TEMPLATES_FILE="Godot_v${GODOT_TEMPLATES_VERSION}-stable_export_templates.tpz"

readonly OS="$(uname)"

GODOT_TEMPLATES_DIR=""

if [[ "$OS" == "Linux" ]]; then
  GODOT_TEMPLATES_DIR="$HOME/.local/share/godot/templates/${GODOT_TEMPLATES_VERSION}.stable"
elif [[ "$OS" == "Darwin" ]]; then
  GODOT_TEMPLATES_DIR="$HOME/Library/Application Support/Godot/templates/${GODOT_TEMPLATES_VERSION}.stable"
else
  echo "ERROR: Supported OSes: 'Linux', 'Darwin'." >&2
  exit 1
fi

if [[ ! -d "$GODOT_TEMPLATES_DIR" ]]; then
  mkdir "$GODOT_TEMPLATES_DIR"

  echo
  echo "> Downloading Godot templates for v$GODOT_TEMPLATES_VERSION..."
  echo
  curl --progress-bar https://downloads.tuxfamily.org/godotengine/$GODOT_TEMPLATES_VERSION/$GODOT_TEMPLATES_FILE -o "$GODOT_TEMPLATES_DIR/$GODOT_TEMPLATES_FILE"
  echo "Done!"

  echo
  echo "> Uncompressing '$GODOT_TEMPLATES_FILE'..."
  tar -xzf "$GODOT_TEMPLATES_DIR/$GODOT_TEMPLATES_FILE" --strip-components=1 -C "$GODOT_TEMPLATES_DIR"
  echo "Done!"
  rm "$GODOT_TEMPLATES_DIR/$GODOT_TEMPLATES_FILE"

  echo
  echo "Godot templates for v$GODOT_TEMPLATES_VERSION installed successfully!"
  echo
fi

PROJECT_NAME=""
PROJECT_NAME_SNAKE_CASE=""
PROJECT_NAME_INITIALS=""
PROJECT_DESCRIPTION=""
PROJECT_VERSION=""
PROJECT_AUTHOR=""

FILE_NAME=""

EXPORT_PLATFORMS=()

function get_config() {
  local value
  local file

  file="$PROJECT_FILE"
  if [[ -n "$2" ]]; then
    file="$2"
  fi
 
  value="$(grep "$1" "$file" | cut -d= -f2)"
  echo "${value//\"/}"
}


function set_config() {
  local file

  file="$EXPORT_PRESETS_FILE"
  if [[ -n "$3" ]]; then
    file="$3"
  fi

  sed -i.bak "s|^\($1\s*=\s*\).*|\1\"$2\"|" "$file" && rm "${file}.bak"
}

function ctrl_c() {
  echo >&2
  echo >&2
  echo "Cancelled by the user!" >&2
  echo >&2

  if [[ -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi

  if [[ -d "$EXPORT_PRESETS_FILE" ]]; then
    rm -rf "$EXPORT_PRESETS_FILE"
  fi

  exit 1
}

trap ctrl_c TERM INT

if [[ -n "$1" ]]; then
  if [[ "$1" == "--platforms" ]] || [[ "$1" == "-p" ]]; then
    echo
    echo "Available platforms:"
    echo "--------------------"
    echo
    while IFS='=' read -r key value ; do
      if [[ "$key" == "name" ]]; then
        echo "$value"
      fi
    done < "$EXPORT_PRESETS_TEMPLATE_FILE"
    echo
    exit 0
  else
    for platform in "$@"; do
      EXPORT_PLATFORMS+=("\"$platform\"")
    done
  fi
else
  while IFS='=' read -r key value ; do
    if [[ "$key" == "name" ]]; then
      EXPORT_PLATFORMS+=("$value")
    fi
  done < "$EXPORT_PRESETS_TEMPLATE_FILE"
fi

cp "$EXPORT_PRESETS_TEMPLATE_FILE" "$EXPORT_PRESETS_FILE"

PROJECT_NAME="$(get_config "config/name")"
set_config "application/product_name" "$PROJECT_NAME"
set_config "application/name" "$PROJECT_NAME"

PROJECT_NAME_INITIALS="$(echo $PROJECT_NAME | sed 's/\(.\)[^ ]* */\1/g')"

PROJECT_DESCRIPTION="$(get_config "config/description")"
set_config "application/file_description" "$PROJECT_DESCRIPTION"
set_config "application/info" "$PROJECT_DESCRIPTION"

PROJECT_VERSION="$(get_config "config/version")"
set_config "application/file_version" "$PROJECT_VERSION"
set_config "application/product_version" "$PROJECT_VERSION"
set_config "application/version" "$PROJECT_VERSION"
set_config "application/short_version" "$PROJECT_VERSION"

PROJECT_AUTHOR="$(get_config "config/author")"
set_config "application/company_name" "$PROJECT_AUTHOR"
set_config "application/copyright" "$PROJECT_AUTHOR"
set_config "application/identifier" "com.${PROJECT_AUTHOR}.${PROJECT_NAME_INITIALS}"

PROJECT_NAME_SNAKE_CASE="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
PROJECT_NAME_SNAKE_CASE="${PROJECT_NAME_SNAKE_CASE// /_}"
PROJECT_NAME_SNAKE_CASE="${PROJECT_NAME_SNAKE_CASE//-/_}"

FILE_NAME="${PROJECT_NAME_SNAKE_CASE}_${PROJECT_VERSION}"

sed -i.bak '/name="Raspberry Pi 32"/,/custom_template\/release/ s|custom_template/release=.*|custom_template/release="'$RPI_32_EXPORT_TEMPLATE_BINARY'"|' "$EXPORT_PRESETS_FILE" && rm "${EXPORT_PRESETS_FILE}.bak"

sed -i.bak '/name="Raspberry Pi 64"/,/custom_template\/release/ s|custom_template/release=.*|custom_template/release="'$RPI_64_EXPORT_TEMPLATE_BINARY'"|' "$EXPORT_PRESETS_FILE" && rm "${EXPORT_PRESETS_FILE}.bak"

mkdir -p "$BUILDS_DIR"

if [[ -d "$BUILDS_DIR/$PROJECT_VERSION" ]]; then
  rm -rf "$BUILDS_DIR/$PROJECT_VERSION"
fi

mkdir -p "$BUILDS_DIR/$PROJECT_VERSION"

echo
echo "----------"
echo "Name: $PROJECT_NAME"
echo "Description: $PROJECT_DESCRIPTION"
echo "Version: $PROJECT_VERSION"
echo "Author: $PROJECT_AUTHOR"
echo "----------"

for i in "${!EXPORT_PLATFORMS[@]}"; do
  mkdir -p "$TMP_DIR"

  platform="${EXPORT_PLATFORMS[i]}"

  if [[ "$platform" =~ "windows" ]]; then
    platform_name="windows"
    extension="exe"
  fi

  if [[ "$platform" =~ "mac" ]]; then
    platform_name="macos"
    extension="zip"
  fi

  if [[ "$platform" =~ "linux" ]]; then
    platform_name="linux"
    extension="x86"
  fi

  if [[ "$platform" =~ "raspberry" ]]; then
    platform_name="raspberrypi"
    extension="arm"
  fi

  if [[ "$platform" =~ "32" ]]; then
    platform_name+="_32"
  fi

  if [[ "$platform" =~ "64" ]]; then
    if [[ "$platform_name" =~ "linux"|"raspberrypi" ]]; then
      extension+="_64"
    fi

    platform_name+="_64"
  fi

  echo
  echo "> Exporting $platform..."

  eval "$GODOT_HEADLESS_BINARY" --quiet --export "$platform" "${TMP_DIR}/${FILE_NAME}_${platform_name}.${extension}"

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

rm "$EXPORT_PRESETS_FILE"

echo
echo "Finished!"

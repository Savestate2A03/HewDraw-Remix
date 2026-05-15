#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$repo_root"

mod_name="${HDR_MOD_NAME:-hdr-dev}"
version="${HDR_VERSION:-v1.69.420-dev}"
output_dir="$repo_root/target/hdr-switch"
mod_dir="$output_dir/ultimate/mods/$mod_name"
plugin_source="$repo_root/target/aarch64-skyline-switch/release/libhdr.nro"
deploy_config="$repo_root/scripts/BUILD-WSL-2026.ini"

trim() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "$value"
}

read_ultimate_path_user() {
	local value=""
	value="$(sed -nE 's/^[[:space:]]*ULTIMATE_PATH_USER[[:space:]]*=(.*)$/\1/p' "$deploy_config" | tail -n 1 || true)"
	value="$(trim "$value")"

	if [[ "$value" == \"*\" && "$value" == *\" ]]; then
		value="${value:1:${#value}-2}"
	elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
		value="${value:1:${#value}-2}"
	fi

	printf '%s' "$value"
}

copy_to_configured_ultimate_folder() {
	if [[ ! -f "$deploy_config" ]]; then
		return 0
	fi

	local ultimate_path destination candidate
	ultimate_path="$(read_ultimate_path_user)"

	if [[ -z "$ultimate_path" ]]; then
		echo "Skipping copy: ULTIMATE_PATH_USER was not found in $deploy_config"
		return 0
	fi

	if [[ ! -d "$ultimate_path" ]]; then
		echo "Skipping copy: folder does not exist: $ultimate_path"
		return 0
	fi

	destination=""
	for candidate in "$ultimate_path/hdr" "$ultimate_path/hdr-dev"; do
		if [[ -d "$candidate" ]]; then
			destination="$candidate"
			break
		fi
	done

	if [[ -z "$destination" ]]; then
		echo "Skipping copy: no hdr or hdr-dev folder found in $ultimate_path"
		return 0
	fi

	echo "Copying release to $destination"
	find "$destination" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
	cp -r "$mod_dir/." "$destination/"
}

echo "Building HDR release"
echo "Output: $output_dir"

printf '%s' "$version" > "$repo_root/hdr_version.txt"

rm -rf "$output_dir"
mkdir -p "$mod_dir"

cargo skyline build --release --features="main_nro"

if [[ ! -f "$plugin_source" ]]; then
	echo "ERROR: Not created: $plugin_source" >&2
	exit 1
fi

cp "$plugin_source" "$mod_dir/plugin.nro"
cp -a "$repo_root/romfs/source/." "$mod_dir/"
cp "$repo_root/romfs/config.json" "$mod_dir/config.json"
mkdir -p "$mod_dir/ui"
cp "$repo_root/hdr_version.txt" "$mod_dir/ui/hdr_version.txt"

if [[ -d "$repo_root/romfs/build" ]]; then
	cp -a "$repo_root/romfs/build/." "$mod_dir/"
fi

copy_to_configured_ultimate_folder

echo "Done: $output_dir"

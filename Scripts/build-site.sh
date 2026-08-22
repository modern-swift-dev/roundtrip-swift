#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
website_directory="$repository_root/Website"
astro_output_directory="$website_directory/dist"
build_directory="$repository_root/.build"
published_directory="$repository_root/docs"

mkdir -p "$build_directory"
staging_directory="$(mktemp -d "$build_directory/site.XXXXXX")"

cleanup() {
    rm -rf "$staging_directory"
}
trap cleanup EXIT

if [[ ! -f "$website_directory/package.json" ]]; then
    echo "Missing Website/package.json." >&2
    exit 1
fi

npm run build --prefix "$website_directory"

if [[ ! -d "$astro_output_directory" ]]; then
    echo "Website build did not create $astro_output_directory." >&2
    exit 1
fi

cp -R "$astro_output_directory/." "$staging_directory"
printf '\n' > "$staging_directory/.nojekyll"

bash "$repository_root/Scripts/build-static-documentation.sh" --output-directory "$staging_directory"
node "$website_directory/scripts/check-internal-links.mjs" "$staging_directory"

case "$published_directory" in
    "$repository_root"/*) ;;
    *)
        echo "Refusing to replace a directory outside this repository: $published_directory" >&2
        exit 1
        ;;
esac

rm -rf "$published_directory"
mv "$staging_directory" "$published_directory"
trap - EXIT

echo "Created $published_directory"

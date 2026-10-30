#!/usr/bin/env bash
# Updates source.json to the newest Horizon launcher release.
#   --only-check  only report whether an update exists
#   --ci          write results to $GITHUB_OUTPUT
set -euo pipefail

cd "$(dirname "$0")/.."

ci=false
only_check=false
for arg in "$@"; do
    case "$arg" in
        --ci) ci=true ;;
        --only-check) only_check=true ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

output() {
    if $ci; then
        echo "$1" >> "$GITHUB_OUTPUT"
    fi
}

repo="horizon-rust/horizon"
asset="horizon-launcher-linux-x86_64.tar.gz"

auth=()
if [ -n "${GH_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GH_TOKEN")
fi

# Game builds and launcher builds share the repository; launcher tags are launcher@X.Y.Z.
releases=$(curl -fsSL --retry 5 --retry-all-errors \
    -H "Accept: application/vnd.github+json" "${auth[@]}" \
    "https://api.github.com/repos/$repo/releases?per_page=100")

remote_version=$(echo "$releases" | jq -r --arg asset "$asset" '
    [ .[]
      | select(.draft == false and .prerelease == false)
      | select(.tag_name | startswith("launcher@"))
      | select(any(.assets[]; .name == $asset)) ]
    | first | .tag_name // empty | ltrimstr("launcher@")')
local_version=$(jq -r .version source.json)

if [ -z "$remote_version" ]; then
    echo "No launcher release found" >&2
    exit 1
fi

echo "Checking version... local=$local_version remote=$remote_version"

if [ "$local_version" = "$remote_version" ]; then
    echo "Horizon launcher is up to date"
    output "should_update=false"
    exit 0
fi

echo "Horizon launcher is outdated: $local_version -> $remote_version"
output "should_update=true"

if $only_check; then
    exit 0
fi

url="https://github.com/$repo/releases/download/launcher@$remote_version/$asset"
echo "Prefetching $url"
hash=$(nix store prefetch-file --hash-type sha256 --json "$url" | jq -r .hash)

jq -n --arg version "$remote_version" --arg hash "$hash" \
    '{ version: $version, hash: $hash }' > source.json

echo "Updated Horizon launcher from $local_version to $remote_version"
output "commit_message=chore(update): horizon-launcher $local_version -> $remote_version"

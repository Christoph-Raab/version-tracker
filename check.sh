#!/bin/bash
set -eou pipefail

update_current_version() {
    local name msg
    name="$1"
    msg="$2"
    nvtake -c "$CONFIG" "$name"
    git commit -a -m "$msg"
}

CONFIG=config.toml

echo "Start checking versions..."
nvchecker -c $CONFIG

echo
echo "Processing diff..."
nvcmp -c $CONFIG -j | jq -r '.[] | "\(.name) \(.newver) \(.oldver) \(.delta)"' | while read -r name new old delta; do
    echo "Got: $delta/$name ($old -> $new)"
    if [[ "$delta" == "added" ]]; then
        echo "Tracking $name now!"
        commit_msg="Added $name to be tracked since $new"
    elif [[ "$delta" == "new" ]]; then
        echo "Updating current version for $name..."
        commit_msg="Updated $name to $new"
    else
        echo "Unsupported delta $delta, exiting..."
        exit
    fi
    update_current_version "$name" "$commit_msg"
    echo
done

echo "Done checking version!"
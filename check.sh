#!/bin/bash
set -eou pipefail

update_current_version() {
    local name msg
    name="$1"
    msg="$2"
    nvtake -c "$CONFIG" "$name"
    git add current.json
    git commit -m "$msg"
}

create_github_issue() {
    local name old new title body res payload
    name="$1"
    old="$2"
    new="$3"
    echo "Creating GitHub issue for $name ($old -> $new)"
    title="[Update] $name version $new released (current: $old)"
    body="New version $new of $name released on $(date +%F)"
    payload='{"title": "'"$title"'", "body": "'"$body"'","assignees": ["'"$OWNER"'"]"}'

    res=$(curl -s --retry 2 --connect-timeout 10 -o /dev/null -w "%{http_code}" \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $REPO_PAT" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -d "$payload" \
      "https://api.github.com/repos/$OWNER/$REPO/issues")
    if [[ -z "$res" ]] || { [[ "$res" != 200 ]] && [[ "$res" != 201 ]]; }; then
        echo "Failed to create GitHub issue for $name, got return code $res"
        exit 1
    fi
    sleep 2 # prevent rate limiting
}

CONFIG=config.toml
OWNER="${GITHUB_USER:-"Christoph-Raab"}"
REPO="${GITHUB_REPO:-"version-tracker"}"
if [[ -z ${REPO_PAT:-""} ]]; then
    echo "Missing GitHub PAT! Aborting..."
    exit 1
fi

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
        create_github_issue "$name" "$old" "$new"
    else
        echo "Unsupported delta $delta, exiting..."
        exit
    fi
    update_current_version "$name" "$commit_msg"
    echo
done

echo "Done checking version!"
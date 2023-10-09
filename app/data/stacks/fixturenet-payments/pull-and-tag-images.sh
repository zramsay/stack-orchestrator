#!/bin/bash

old_prefix="git.vdb.to/cerc-io"
new_org="cerc"

# Define an array of Docker images to pull
images_to_pull=(
"git.vdb.to/cerc-io/ponder:local"
"git.vdb.to/cerc-io/mobymask-ui:local"
"git.vdb.to/cerc-io/mobymask-snap:local"
"git.vdb.to/cerc-io/mobymask:local"
"git.vdb.to/cerc-io/watcher-mobymask-v3:local"
"git.vdb.to/cerc-io/watcher-ts:local"
"git.vdb.to/cerc-io/nitro-rpc-client:local"
"git.vdb.to/cerc-io/go-nitro:local"
"git.vdb.to/cerc-io/nitro-contracts:local"
"git.vdb.to/cerc-io/ipld-eth-server:local"
"git.vdb.to/cerc-io/ipld-eth-db:local"
"git.vdb.to/cerc-io/fixturenet-eth-lighthouse:local"
"git.vdb.to/cerc-io/fixturenet-eth-geth:local"
"git.vdb.to/cerc-io/fixturenet-eth-genesis:local"
"git.vdb.to/cerc-io/lighthouse-cli:local"
"git.vdb.to/cerc-io/lighthouse:local"
"git.vdb.to/cerc-io/go-ethereum:local"
)

# Loop through the images and pull them
for image in "${images_to_pull[@]}"; do
    echo "Pulling image: $image"
    docker pull $image
done

echo "Image pull complete."

# Get the list of image IDs with the "local" tag
local_image_ids=$(docker images -q | xargs docker inspect -f '{{.Id}} {{.RepoTags}}' | grep 'local' | awk '{print $1}')

# Loop through the local image IDs and modify the prefixes
for image_id in $local_image_ids; do
    # Get the current repository/tag without any square brackets
    current_repo_tag=$(docker inspect -f '{{.RepoTags}}' $image_id | sed 's/\[//g' | sed 's/\]//g')

    # Extract the image name part after the last "/"
    image_name=${current_repo_tag##*/}

    # Remove the old prefix from the image name
    new_image_name=${image_name#"$old_prefix/"}

    # Create the new repository/tag by combining the new organization and the modified image name
    new_repo_tag="$new_org/$new_image_name"

    # Print the changes
    echo "Changing $current_repo_tag to $new_repo_tag"

    # Tag the image with the new repository/tag
    docker tag $image_id $new_repo_tag
done

echo "Prefix modification complete."

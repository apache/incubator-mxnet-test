#!/bin/bash

web_url="$1"
web_folder="VersionedWeb"
local_build="latest"
web_branch="$2"
git clone $web_url $web_folder
cd $web_folder
git checkout -b $web_branch "origin/$web_branch"
cd ..
mkdir "$local_build"

# Fetch tag information
tag_list_file="tag_list.txt"
cp "$web_folder/tag.txt" "$tag_list_file"
tag_list=()
while read -r line 
do
    tag_list+=("$line")
done < "$tag_list_file"
latest_tag=${tag_list[0]}
echo "latest_tag is: $latest_tag"
commit_id=$(git rev-parse HEAD)
curr_tag=${TAG}
curr_tag=${curr_tag:5}
echo "Current tag is $curr_tag"
if [[ "$curr_tag" != 'master' ]] && [ $curr_tag != $latest_tag ]
then
    latest_tag=$curr_tag
fi

# Build new released tag
if [ $latest_tag != ${tag_list[0]} ]
then
    echo "Building new tag"
    git submodule update
    git checkout $latest_tag
    make docs || exit 1
    echo -e "$latest_tag\n$(cat $tag_list_file)" > "$tag_list_file"
    cat $tag_list_file
    tests/ci_build/ci_build.sh doc python docs/build_version_doc/AddVersion.py --file_path "docs/_build/html/" --current_version "$latest_tag" \
                                                --root_url "http://mxnet.incubator.apache.org/test/"
    cp -a "docs/_build/html/." "$local_build"
    cp $tag_list_file "$local_build/tag.txt"
    rm -rf "$web_folder/.git"
    cp -a "$web_folder/versions/." "$local_build/versions"
    mkdir "$local_build/versions/${tag_list[0]}"
    cp -a "$web_folder/." "$local_build/versions/${tag_list[0]}" || exit 1
    rm -rf "$local_build/versions/${tag_list[0]}/versions"
    rm -rf "$web_folder/*"
    cp -a "$local_build/." "$web_folder"
fi

# Build latest master
git checkout VersionedDoc
git checkout -- .
git submodule update
echo "Building master"
make docs || exit 1

rm -rfv "$web_folder/versions/master/*"
cp -a "docs/_build/html/." "$web_folder/versions/master"
tests/ci_build/ci_build.sh doc python docs/build_version_doc/AddVersion.py --file_path "$web_folder/versions/master" --root_url "http://mxnet.incubator.apache.org/test/"

# Update version list for all previous version website
if [ $latest_tag != ${tag_list[0]} ]
then
    total=${#tag_list[*]}
    for (( i=0; i<=$(( $total -1 )); i++ ))
    do
        tests/ci_build/ci_build.sh doc python docs/build_version_doc/AddVersion.py --file_path "$web_folder/versions/${tag_list[$i]}" \
                                                    --current_version "${tag_list[$i]}" --root_url "http://mxnet.incubator.apache.org/test/"
    done
fi

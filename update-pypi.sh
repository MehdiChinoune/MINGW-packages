#!/bin/bash

git config --global user.email "mehdi.chinoune@hotmail.com"
git config --global user.name "Mehdi Chinoune"
git config --global --unset credential.helper

git fetch --all

nvchecker -c check-pypi.toml --logger json > events.json

declare -a packages=($(jq -r '. | select (.event == "updated") | .name' events.json))
declare -a package_versions=($(jq -r '. | select (.event == "updated") | .version' events.json))

git switch -c updates origin/updates

i=0
for package in ${packages[@]}; do
  if [[ -d mingw-w64-${package} ]]; then
    branch_exist=$(git ls-remote --heads https://github.com/MehdiChinoune/MINGW-packages.git ${package}-update | wc -l)
    if (( ! ${branch_exist} )); then
      git checkout -b ${package}-update updates
    else
      git switch ${package}-update
    fi
    cd mingw-w64-${package}
    new_ver=${package_versions[${i}]}
    sed -e "s|^pkgver=.*|pkgver=${new_ver}|g" -i PKGBUILD
    sed -e "s|^pkgrel=.*|pkgrel=1|g" -i PKGBUILD
    updpkgsums
    cd ..
    sed -e "s|^  \"${package}\":[^,]*|  \"${package}\": \"${new_ver}\"|g" -i oldver-pypi.json
    if [[ `git status --porcelain -- mingw-w64-${package}/PKGBUILD` ]]; then
      git add mingw-w64-${package}/PKGBUILD
      git commit -m "${package}: update to ${new_ver}"
      git push origin ${package}-update
    fi
  fi
  i=$((${i}+1))
done

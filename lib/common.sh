#!/bin/bash

if [ -z "${buildpack}" ]; then
    buildpack=$(cd "$(dirname $0)/.." && pwd)
fi

steptxt="----->"
RED='\033[1;31m'
NC='\033[0m' # No Color
DataJSON="${buildpack}/data.json"
FilesJSON="${buildpack}/files.json"
vendorJSON="${build}/vendor/vendor.json"
CURL="curl -s -L --retry 15 --retry-delay 2"
BucketURL="https://heroku-golang-prod.s3.amazonaws.com"

start() {
    echo -n "$steptxt $@... "
}

err() {
    echo -e >&2 "${RED} !!    $@${NC}"
}

finished() {
    echo "done"
}

ensureInPath() {
    local fileName="${1}"
    local targetDir="${2}"
    local xCmd="${3:-chmod a+x}"
    local targetFile="${targetDir}/jq"
    PATH="${targetDir}:${PATH}"
    ensureFile "${fileName}" "${targetDir}" "${xCmd}"
}

ensureFile() {
    local fileName="${1}"
    local targetDir="${2}"
    local xCmd="${3}"
    local targetFile="${targetDir}/jq"
    downloadFile "${fileName}" "${targetDir}" "${xCmd}"
}

SHAValid() {
    local fileName="${1}"
    local targetFile="${2}"
    local sh=""
    local sw="$(<"${FilesJSON}" jq -r '."'${fileName}'".SHA')"
    if [ ${#sw} -eq 40 ]; then
        sh="$(shasum "${targetFile}" | cut -d \  -f 1)"
    else
        sh="$(shasum -a256 "${targetFile}" | cut -d \  -f 1)"
    fi
    [ "${sh}" = "${sw}" ]
}

downloadFile() {
    local fileName="${1}"
    local targetDir="${2}"
    local xCmd="${3}"
    local localName="jq"
    local targetFile="${targetDir}/${localName}"

    mkdir -p "${targetDir}"
    pushd "${targetDir}" &> /dev/null
        start "Fetching ${localName}"
            ${CURL} -O "${BucketURL}/${fileName}"
            if [ "${fileName}" != "${localName}" ]; then
                mv "${fileName}" "${localName}"
            fi
            if [ -n "${xCmd}" ]; then
                ${xCmd} ${targetFile}
            fi
            if ! SHAValid "${fileName}" "${targetFile}"; then
                err ""
                err "Downloaded file (${fileName}) sha does not match recorded SHA"
                err "Unable to continue."
                err ""
                exit 1
            fi
        finished
    popd &> /dev/null
}

setupGOPATH() {
    local name="${1}"
    local t="$(mktemp -d)"

    cp -R ${build}/* ${t}
    GOPATH="${t}/.go"
    echo export GOBIN="${build}/bin"

    src="${GOPATH}/src/${name}"
    mkdir -p "${src}"
    mkdir -p "${build}/bin"
    mv -t "${src}" "${t}"/*

    echo "GOPATH=${GOPATH}"
    echo "src=${src}"
}

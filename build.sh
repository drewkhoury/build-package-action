#!/bin/bash

set -e
set -x

function die()
{
    local -r message="$1"
    echo "ERROR: ${message}" 1>&2
    exit 1
}

if [[ ! -d debian ]]; then
    die 'The `debian/` directory not found in the repository root'
fi

declare -r PN=$(head -n1 debian/changelog | sed 's,\([^ ]\+\).*,\1,')
declare -r PV=$(head -n1 debian/changelog | sed 's,^[^(]\+(\([0-9]\+\(\.[0-9]\+\)*\(-rc[0-9]\)\?\).*,\1,')

if [[ -e ./build.sh ]]; then
    . ./build.sh
else
    die 'The repository must have the `./build.sh` script'
fi

mkdir -pv build
cd build

if [[ -n ${DOWNLOAD} ]]; then
    declare -r _upstream_filename=${DOWNLOAD##/*}
    declare -r _upstream_ext=${_upstream_filename#*.}
    wget -c -O ${PN}_${PV}.orig.${_upstream_ext} ${DOWNLOAD}
else
    die 'The `./build.sh` script must export the `DOWNLOAD` variable set to the URL of the package tarball'
fi

mkdir -pv "${PN}_${PV}"
cd "${PN}_${PV}"

tar -xf ../${PN}_${PV}.orig.${_upstream_ext} --strip-components=1

cp --reflink=auto -vr ../../debian .

if [[ $(type -t src_prepare) == 'function' ]]; then
    src_prepare
fi

apt-get update

mk-build-deps -i -r -t 'apt-get -y'

DEB_BUILD_OPTIONS="parallel=$(nproc) nocheck" dpkg-buildpackage -uc

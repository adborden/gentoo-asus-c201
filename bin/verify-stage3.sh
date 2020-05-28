#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x

stage3=$1
workdir=$(dirname $stage3)

gpg --recv-keys 534E4209AB49EEE1C19D96162C44695DB9F6043D
gpg --verify $stage3.DIGESTS.asc

cd $workdir && sha512sum -c <(sed -n '/SHA512/ { n; /tar.xz$/ p }' $(basename $stage3.DIGESTS.asc))

#! /bin/bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # display expanded commands and arguments

pushd /nvidia-jetpack/Linux_for_Tegra &>/dev/null
printf "Running apply_binaries.sh ...\n"
./apply_binaries.sh
popd &>/dev/null

##
## jetpack-l4t config
##

declare -A DEFAULT_UBUNTU_VERSION_MAP=(
    ["35.4.1"]="20.04"
    ["35.3.1"]="20.04"
    ["35.2.1"]="20.04"
)

declare -A BOARDCTL_PLATFORM_ARRAY=(
    ["agxorin"]="topo"
)

declare -a PLATFORM_ARRAY=(
    "agxorin"
    "igxorin"
    "orinnx"
    "orinnano"
    "xaviernx"
)

declare -a JETPACK_FIRMWARE_RELEASE_ARRAY=(
    "35.4.1"
    "35.3.1"
    "35.2.1"
)

declare -A JETPACK_BOARD_CONFIG_MAP=(
    ["agxorin"]="jetson-agx-orin-devkit"
    ["igxorin"]="jetson-igx-orin-devkit"
    ["orinnx"]="jetson-orin-nx-devkit"
    ["orinnano"]="jetson-orin-nano-devkit"
    ["xaviernx"]="jetson-xavier-nx-devkit"
)

declare -A JETPACK_DRIVER_BSP_MAP=(
    ["35.4.1"]="Jetson_Linux_R35.4.1_aarch64.tbz2"
    ["35.3.1"]="Jetson_Linux_R35.3.1_aarch64.tbz2"
    ["35.2.1"]="Jetson_Linux_R35.2.1_aarch64.tbz2"
)

declare -A JETPACK_DRIVER_BSP_URI_MAP=(
    ["35.4.1"]="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v4.1/release/jetson_linux_r35.4.1_aarch64.tbz2"
    ["35.3.1"]="https://developer.download.nvidia.com/embedded/L4T/r35_Release_v3.1/release/Jetson_Linux_R35.3.1_aarch64.tbz2"
    ["35.2.1"]="https://developer.nvidia.com/downloads/jetson-linux-r3521-aarch64tbz2"
)

declare -A JETPACK_ROOT_FS_MAP=(
    ["35.4.1"]="Tegra_Linux_Sample-Root-Filesystem_R35.4.1_aarch64.tbz2"
    ["35.3.1"]="tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2"
    ["35.2.1"]="Tegra_Linux_Sample-Root-Filesystem_R35.2.1_aarch64.tbz2"
)

declare -A JETPACK_ROOT_FS_URI_MAP=(
    ["35.4.1"]="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v4.1/release/tegra_linux_sample-root-filesystem_r35.4.1_aarch64.tbz2"
    ["35.3.1"]="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v3.1/release/tegra_linux_sample-root-filesystem_r35.3.1_aarch64.tbz2"
    ["35.2.1"]="https://developer.nvidia.com/downloads/linux-sample-root-filesystem-r3521aarch64tbz2"
)

declare -a PODMAN_BUILD_ARGS=(
    --cap-add=all
    --squash-all
)

declare -a PODMAN_RUN_ARGS=(
    --rm
    --interactive
    --tty
    --privileged
    --name ${IMAGE_NAME}
    --volume /dev:/dev
    --volume /sys:/sys
)

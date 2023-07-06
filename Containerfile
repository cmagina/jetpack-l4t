ARG UBUNTU_VERSION=20.04
ARG IMAGE=docker.io/library/ubuntu:${UBUNTU_VERSION}

FROM ${IMAGE} as install-bsp

ARG JETSON_FIRMWARE_RELEASE
ARG JETSON_DRIVER_BSP
ARG JETSON_ROOT_FS
ARG JETSON_BSP_OVERLAY
ARG BSP_DOWNLOADS

COPY ${BSP_DOWNLOADS}/* /tmp/

RUN mkdir -p /bsp-files; \
    echo JETSON_FIRMWARE_RELEASE=${JETSON_FIRMWARE_RELEASE} > /bsp-files/build.manifest; \
    printf "Extracting %s to %s ...\n" ${JETSON_DRIVER_BSP} /bsp-files; \
    tar --extract --file=/tmp/${JETSON_DRIVER_BSP} --directory=/bsp-files; \
    echo JETSON_DRIVER_BSP=${JETSON_DRIVER_BSP} >> /bsp-files/build.manifest; \
    \
    if [ -f "/tmp/${JETSON_ROOT_FS}" ]; then \
    printf "Extracting %s to %s/Linux_for_Tegra/rootfs ...\n" ${JETSON_ROOT_FS} /bsp-files; \
    tar --extract --file=/tmp/${JETSON_ROOT_FS} --directory=/bsp-files/Linux_for_Tegra/rootfs; \
    echo JETSON_ROOT_FS=${JETSON_ROOT_FS} >> /bsp-files/build.manifest; \
    else \
    printf "Not installing a root filesystem.\n"; \
    fi; \
    \
    if [ -f "/tmp/${JETSON_BSP_OVERLAY}" ]; then \
    printf "Extracting %s to %s ...\n" ${JETSON_BSP_OVERLAY} /bsp-files; \
    tar --extract --file=/tmp/${JETSON_BSP_OVERLAY} --directory=/bsp-files; \
    echo JETSON_BSP_OVERLAY=${JETSON_BSP_OVERLAY} >> /bsp-files/build.manifest; \
    fi

FROM ${IMAGE} as setup-bsp

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C

ARG SOFTWARE_DEPS_LIST="iproute2 perl sudo usbutils"
RUN printf "Updating the package cache ...\n"; \
    apt-get --yes update; \
    printf "Upgrading the image ...\n"; \
    apt-get --yes upgrade; \
    printf "Installing software ...\n"; \
    apt-get --yes install ${SOFTWARE_DEPS_LIST}; \
    printf "Cleaning up ...\n"; \
    rm --recursive --force /var/lib/apt/lists/*

ENV WORKDIR=/nvidia-jetson
WORKDIR ${WORKDIR}

COPY --from=install-bsp /bsp-files ${WORKDIR}

WORKDIR ${WORKDIR}/Linux_for_Tegra
RUN ./tools/l4t_flash_prerequisites.sh

ARG SETUP_SCRIPT=files/bsp-setup.sh
COPY --chmod=0750 ${SETUP_SCRIPT} /tmp/bsp-setup.sh
RUN if [ -n "${SETUP_SCRIPT}" ]; then \
    /tmp/bsp-setup.sh && \
    rm --force /tmp/bsp-setup.sh; \
    fi

COPY --chmod=0750 files/entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

# This Dockerfile creates an image suitable to run OP-TEE OS CI tests
# in the QEMUv8 environment [1]. It pulls Ubuntu plus all the required
# packages.
#
# [1] https://optee.readthedocs.io/en/latest/building/devices/qemu.html#qemu-v8

FROM ubuntu as gcc-builder
MAINTAINER Volodymyr Babchuk <volodymyr_babchuk@epam.com>

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update \
 && apt upgrade -y \
 && apt install -y \
  binutils \
  build-essential \
  bison \
  flex \
  gawk \
  git \
  gcc \
  help2man \
  libncurses5-dev \
  libtool \
  libtool-bin \
  python3-dev \
  python3-setuptools \
  texinfo \
  unzip \
  wget

RUN useradd -ms /bin/bash nonroot
USER nonroot
WORKDIR /home/nonroot

# Build and install cross-compiler with BTI support in ~nonroot/x-tools/aarch64-unknown-linux-gnu/bin
# This particular commit of crosstool-ng builds GCC 12.2.0 by default which is what we want
# (13.x does not work with C++ TAs)
RUN git clone https://github.com/crosstool-ng/crosstool-ng \
 && cd crosstool-ng \
 && git checkout aa6cc4d7 \
 && ./bootstrap \
 && ./configure --enable-local \
 && make -j$(nproc) \
 && ./ct-ng aarch64-unknown-linux-uclibc \
 && echo 'CT_CC_GCC_EXTRA_CONFIG_ARRAY="--enable-standard-branch-protection"' >>.config \
 && echo 'CT_CC_GCC_CORE_EXTRA_CONFIG_ARRAY="--enable-standard-branch-protection"' >>.config \
 && ./ct-ng build.$(nproc)

ARG ZEPHYR_SDK_VER="0.16.8"

RUN wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VER}/zephyr-sdk-${ZEPHYR_SDK_VER}_linux-x86_64.tar.xz && \
  tar xvf zephyr-sdk-${ZEPHYR_SDK_VER}_linux-x86_64.tar.xz && \
  rm zephyr-sdk-${ZEPHYR_SDK_VER}_linux-x86_64.tar.xz && \
  cd zephyr-sdk-${ZEPHYR_SDK_VER}/ && \
  rm -rf arc-zephyr-elf \
	arc64-zephyr-elf \
	arm-zephyr-eabi \
	microblazeel-zephyr-elf \
	mips-zephyr-elf \
	nios2-zephyr-elf \
	riscv64-zephyr-elf \
	sparc-zephyr-elf \
	x86_64-zephyr-elf \
	xtensa-dc233c_zephyr-elf \
	xtensa-espressif_esp32_zephyr-elf \
	xtensa-espressif_esp32s2_zephyr-elf \
	xtensa-espressif_esp32s3_zephyr-elf \
	xtensa-intel_ace15_mtpm_zephyr-elf \
	xtensa-intel_tgl_adsp_zephyr-elf \
	xtensa-mtk_mt8195_adsp_zephyr-elf \
	xtensa-nxp_imx8m_adsp_zephyr-elf \
	xtensa-nxp_imx8ulp_adsp_zephyr-elf \
	xtensa-nxp_imx_adsp_zephyr-elf \
	xtensa-nxp_rt500_adsp_zephyr-elf \
	xtensa-nxp_rt600_adsp_zephyr-elf \
	xtensa-sample_controller_zephyr-elf

FROM ubuntu:22.04
MAINTAINER Volodymyr Babchuk <volodymyr_babchuk@epam.com>

RUN mkdir -p /usr/local
COPY --from=gcc-builder /home/nonroot/x-tools/aarch64-unknown-linux-uclibc /usr/local/

RUN apt-get update \
 && apt-get install -y wget

RUN wget https://apt.kitware.com/kitware-archive.sh \
 && bash  kitware-archive.sh

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y \
  acpica-tools \
  android-tools-fastboot \
  autoconf \
  bc \
  bison \
  bzip2 \
  ccache \
  cmake \
  cpio \
  curl \
  device-tree-compiler \
  expect \
  file \
  flex \
  g++ \
  gdisk \
  gettext \
  git \
  gpg \
  libattr1-dev \
  libcap-ng-dev \
  libglib2.0-dev \
  libgmp-dev \
  libguestfs-tools \
  libmpc-dev \
  libpixman-1-dev \
  linux-image-kvm \
  libslirp-dev \
  libssl-dev \
  lsb-release \
  make \
  ninja-build \
  pkg-config \
  python-is-python3 \
  python3 \
  python3-cryptography \
  python3-cryptography \
  python3-distutils \
  python3-pycryptodome \
  python3-pyelftools \
  python3-venv \
  python3-pip \
  rsync \
  sudo \
  unzip \
  uuid-dev \
  vim \
  xz-utils \
 && apt-get autoremove

RUN pip3 install west

ARG ZEPHYR_SDK_VER="0.16.8"
COPY --from=gcc-builder /home/nonroot/zephyr-sdk-${ZEPHYR_SDK_VER} /opt/

RUN cd /opt \
 && ./setup.sh -h -c -t aarch64-zephyr-elf

RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo \
 && chmod a+x /usr/local/bin/repo \
 && git config --global user.name "CI user" \
 && git config --global user.email "ci@invalid"

COPY get_optee_qemuv8.sh /root
COPY get_zephyr.sh /root

RUN chmod +rx /root
RUN chmod +x /root/get_optee_qemuv8.sh
RUN chmod +x /root/get_zephyr.sh

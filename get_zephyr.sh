#!/bin/bash
#
# 1. Get zephyr test app
# 2. Build id

ROOT_DIR=/root/optee_repo_qemu_v8

set -e
mkdir -p ${ROOT_DIR}
cd ${ROOT_DIR}

west init -m https://github.com/xen-troops/zephyr-optee-test.git zephyr-optee
cd zephyr-optee
west update


# SPDX-License-Identifier: Apache-2.0
#
# Backwards-compatibility shim — see generic.cmake in this directory.
# Delegate all target-toolchain configuration to the canonical host/llvm
# implementation so this shim tracks upstream behaviour automatically.

include(${ZEPHYR_BASE}/cmake/toolchain/host/llvm/target.cmake)

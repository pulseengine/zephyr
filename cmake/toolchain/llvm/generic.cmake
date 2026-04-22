# SPDX-License-Identifier: Apache-2.0
#
# Backwards-compatibility shim for the legacy ``ZEPHYR_TOOLCHAIN_VARIANT=llvm``
# variant name.
#
# Upstream Zephyr (commit 180f667812f, "cmake: toolchain: combine host
# variants", May 2025) consolidated the standalone ``llvm`` variant under
# ``host/llvm``. v4.4.0-rc3 (the base of this fork) already carries that
# change, so ``cmake/toolchain/llvm/`` no longer exists in the upstream tree.
#
# Gale's CI (``.github/workflows/llvm-lto.yml``) and a number of our internal
# documents still pass ``-DZEPHYR_TOOLCHAIN_VARIANT=llvm``. Rather than chase
# every call site on every rebase, this shim reroutes the legacy variant name
# onto the supported ``host/llvm`` configuration. It also leaves
# ``ZEPHYR_TOOLCHAIN_VARIANT`` equal to ``llvm`` so that downstream CMake
# checks (e.g. Gale's ``zephyr/CMakeLists.txt`` cross-language-LTO guard)
# continue to match.

set(TOOLCHAIN_VARIANT_COMPILER llvm CACHE STRING
    "compiler used by the toolchain variant" FORCE)

include(${ZEPHYR_BASE}/cmake/toolchain/host/llvm/generic.cmake)

# FindHostTools.cmake defaults TOOLCHAIN_KCONFIG_DIR to
# ``${TOOLCHAIN_ROOT}/cmake/toolchain/${ZEPHYR_TOOLCHAIN_VARIANT}`` (i.e. the
# shim directory). Redirect it at the real Kconfig under ``host/llvm`` so the
# usual ``CONFIG_LLVM_USE_LD`` / ``CONFIG_LLVM_USE_LLD`` choice is available.
set(TOOLCHAIN_KCONFIG_DIR ${ZEPHYR_BASE}/cmake/toolchain/host/llvm)

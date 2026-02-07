# Note that this script can be run with `julia build_tarballs.jl --hierarchical-environment`
# to locally build ntl_jll for the current platform

using BinaryBuilder, Pkg

name = "ntl"
version = v"11.6.0"

# Collection of sources required to build NTL
sources = [
    ArchiveSource("https://libntl.org/ntl-$(version).tar.gz",
                  "bc0ef9aceb075a6a0673ac8d8f47d5f8458c72fe806e4468fbd5d3daff056182"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/ntl-*/src

# NTL configure script uses non-standard syntax: variable=value
# NATIVE=off: disable -march=native for cross-compilation
# TUNE=generic: use generic tuning for cross-compilation (avoids running GenConfigInfo)
# SHARED=on: build shared library using libtool

# Common configure options
CONFIGURE_OPTS=(
    PREFIX="${prefix}"
    GMP_PREFIX="${prefix}"
    NATIVE=off
    TUNE=generic
    SHARED=on
    CXX="${CXX}"
    CXXFLAGS="${CXXFLAGS}"
)

if [[ "${target}" == *-mingw* ]]; then
    # Windows/MinGW: need -no-undefined for shared libraries
    # See NTL config.txt: "On Cygwin, for obscure reasons, you may have to use
    # the option LIBTOOL_LINK_FLAGS=-no-undefined" - same applies to MinGW
    CONFIGURE_OPTS+=(LIBTOOL_LINK_FLAGS="-no-undefined")
fi

./configure "${CONFIGURE_OPTS[@]}"

make -j${nproc}
make install

install_license ../doc/copying.txt
"""

# Platforms to build for
# NTL is a C++ library, so we need to expand for C++ string ABI
platforms = supported_platforms()

# Filter out platforms that might have issues
# FreeBSD support is experimental for many C++ libraries
platforms = filter(!Sys.isfreebsd, platforms)

# Expand C++ string ABIs for Linux
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libntl", :libntl),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("GMP_jll"; compat="6.2.1"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"7")

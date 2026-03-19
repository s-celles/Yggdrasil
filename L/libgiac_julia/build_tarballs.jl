# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg
using Base.BinaryPlatforms

name = "libgiac_julia"
version = v"0.5.0"

# Collection of sources required to build libgiac_julia
sources = [
    GitSource(
        "https://github.com/s-celles/libgiac-julia-wrapper.git",
        "490207923b75678ace5409e16ed5bc134bd9c7d9"
    ),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/libgiac-julia-wrapper

# CMake is needed by meson to find JlCxx (libcxxwrap-julia)
apk add cmake

# Meson cross-compilation setup
# Use the GCC variant of the toolchain for C++ ABI compatibility with GIAC_jll
if [[ -f "${MESON_TARGET_TOOLCHAIN%.*}_gcc.meson" ]]; then
    MESON_CROSS="${MESON_TARGET_TOOLCHAIN%.*}_gcc.meson"
else
    MESON_CROSS="${MESON_TARGET_TOOLCHAIN}"
fi

# Inject cmake path into the cross-file so meson can find JlCxx
CMAKE_PATH=$(which cmake)
sed -i "/^\[binaries\]/a cmake = '${CMAKE_PATH}'" "${MESON_CROSS}"

# Tell meson where to find JlCxx (libcxxwrap-julia) via CMake
# and where GIAC headers are installed
# Pass Julia headers include path via meson cpp_args (cross builds ignore env CXXFLAGS)
meson setup builddir \
    --cross-file="${MESON_CROSS}" \
    --prefix="${prefix}" \
    --buildtype=release \
    -Dgiac_include_dir="${includedir}/giac" \
    -Dcpp_args="-I${includedir}/julia -I${includedir}/giac" \
    --cmake-prefix-path="${prefix}"

# Only build the wrapper library (skip tests - they require a running Julia)
meson compile -C builddir -j${nproc} giac_wrapper

# Install manually (meson install rebuilds all targets including tests)
mkdir -p ${libdir}
find builddir/src -maxdepth 1 -name "libgiac_wrapper*" -type f -exec cp {} ${libdir}/ \;
# Create soname symlinks
cd ${libdir}
if [[ -f libgiac_wrapper.so.0.5.0 ]]; then
    ln -sf libgiac_wrapper.so.0.5.0 libgiac_wrapper.so.0
    ln -sf libgiac_wrapper.so.0 libgiac_wrapper.so
fi
cd -
mkdir -p ${includedir}/giac_julia
cp src/giac_impl.h ${includedir}/giac_julia/

install_license LICENSE
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
include("../../L/libjulia/common.jl")
platforms = vcat(libjulia_platforms.(julia_versions)...)
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("libgiac_wrapper", :libgiac_wrapper),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency(PackageSpec(;name="libjulia_jll", version=v"1.11.0+0")),
    Dependency("libcxxwrap_julia_jll"),
    Dependency("Gettext_jll"; compat="0.21.0"),
    Dependency("GMP_jll"; compat="6.2.1"),
    Dependency("MPFR_jll"; compat="4.2.1"),
    Dependency("Readline_jll"; compat="8.2.13"),
    Dependency("GIAC_jll"; compat="2.0.1"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version=v"9", julia_compat=libjulia_julia_compat(julia_versions))

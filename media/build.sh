set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${MISE_MEDIA_BUILD_ROOT:-$(mktemp -d -t mise-media-XXXXXXXX)}"
mkdir -p "$WORK"
if [[ -n "$(find "$WORK" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  printf 'The media build directory must be empty.\n' >&2
  exit 1
fi
WORK="$(cd "$WORK" && pwd)"
PREFIX="$WORK/prefix"
DIST="$ROOT/dist"
JOBS="${MISE_MEDIA_JOBS:-$(nproc)}"
mkdir -p "$PREFIX" "$DIST" "$WORK/downloads" "$WORK/src" "$WORK/build" "$WORK/metadata"
exec > >(tee "$WORK/metadata/build.log") 2>&1
export SOURCE_DATE_EPOCH="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sourceDateEpoch"])' "$ROOT/sources.json")"
export TZ=UTC LC_ALL=C
export CC=x86_64-w64-mingw32-gcc-posix CXX=x86_64-w64-mingw32-g++-posix
export AR=x86_64-w64-mingw32-ar RANLIB=x86_64-w64-mingw32-ranlib
export STRIP=x86_64-w64-mingw32-strip WINDRES=x86_64-w64-mingw32-windres
export CFLAGS="-O2 -D_WIN32_WINNT=0x0601 -ffile-prefix-map=$WORK=/mise-build"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-static -static-libgcc -static-libstdc++ -Wl,--no-insert-timestamp"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG="pkg-config --static"

python3 - "$ROOT" "$WORK" <<'PY'
import hashlib, json, pathlib, shutil, sys, tarfile, urllib.request
root, work = map(pathlib.Path, sys.argv[1:])
manifest = json.loads((root / 'sources.json').read_text())
for package in manifest['packages']:
    destination = work / 'downloads' / package['file']
    local = root / 'sources' / package['file']
    if local.is_file():
        shutil.copyfile(local, destination)
    else:
        with urllib.request.urlopen(package['url'], timeout=180) as response, destination.open('wb') as output:
            shutil.copyfileobj(response, output)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    if digest != package['sha256']:
        raise SystemExit('Source checksum mismatch: ' + package['name'])
    target = work / 'src' / package['name']
    target.mkdir()
    with tarfile.open(destination) as archive:
        members = archive.getmembers()
        top = pathlib.PurePosixPath(members[0].name).parts[0]
        for member in members:
            parts = pathlib.PurePosixPath(member.name).parts
            if not parts or parts[0] != top:
                raise SystemExit('Unexpected archive root: ' + package['name'])
            if len(parts) == 1:
                continue
            member.name = str(pathlib.PurePosixPath(*parts[1:]))
            archive.extract(member, target, filter='data')
    print('Verified and extracted:', package['name'], digest, flush=True)
PY

cat > "$WORK/cross.ini" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
windres = '$WINDRES'
pkg-config = 'pkg-config'
[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
[properties]
needs_exe_wrapper = true
[built-in options]
c_args = ['-O2', '-D_WIN32_WINNT=0x0601', '-ffile-prefix-map=$WORK=/mise-build']
cpp_args = ['-O2', '-D_WIN32_WINNT=0x0601', '-ffile-prefix-map=$WORK=/mise-build']
c_link_args = ['-static', '-static-libgcc', '-Wl,--no-insert-timestamp']
cpp_link_args = ['-static', '-static-libgcc', '-static-libstdc++', '-Wl,--no-insert-timestamp']
EOF

cat > "$WORK/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
set(CMAKE_RC_COMPILER $WINDRES)
set(CMAKE_FIND_ROOT_PATH "$PREFIX" /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_C_FLAGS "$CFLAGS")
set(CMAKE_CXX_FLAGS "$CXXFLAGS")
set(CMAKE_EXE_LINKER_FLAGS "$LDFLAGS")
EOF

cmake_build() {
  local name="$1"
  shift
  cmake -S "$WORK/src/$name" -B "$WORK/build/$name" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$WORK/toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF "$@"
  cmake --build "$WORK/build/$name" --parallel "$JOBS"
  cmake --install "$WORK/build/$name"
}

meson_build() {
  local name="$1"
  shift
  meson setup "$WORK/build/$name" "$WORK/src/$name" --cross-file "$WORK/cross.ini" \
    --prefix "$PREFIX" --libdir lib --buildtype release --default-library static --wrap-mode nofallback "$@"
  meson compile -C "$WORK/build/$name" -j "$JOBS"
  meson install -C "$WORK/build/$name"
}

cmake_build zlib -DZLIB_BUILD_EXAMPLES=OFF -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON
cmake_build expat -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF \
  -DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_DOCS=OFF -DEXPAT_CHAR_TYPE=char -DEXPAT_WARNINGS_AS_ERRORS=OFF
cmake_build freetype -DFT_DISABLE_ZLIB=OFF -DFT_REQUIRE_ZLIB=ON -DZLIB_ROOT="$PREFIX" \
  -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON
meson_build fontconfig -Ddoc=disabled -Dnls=disabled -Dtests=disabled -Dtools=disabled \
  -Dcache-build=disabled -Diconv=disabled -Dxml-backend=expat -Dfontations=disabled
meson_build fribidi -Ddocs=false -Dbin=false -Dtests=false
meson_build harfbuzz -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled \
  -Dpng=disabled -Dzlib=disabled -Dicu=disabled -Dfreetype=enabled -Dtests=disabled \
  -Dintrospection=disabled -Ddocs=disabled -Dutilities=disabled -Draster=disabled \
  -Dvector=disabled -Dgpu=disabled -Dgpu_demo=disabled -Dsubset=disabled
(
  cd "$WORK/src/libass"
  ./configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --disable-shared --enable-static \
    --enable-fontconfig --enable-directwrite
  make -j "$JOBS"
  make install
)
(
  cd "$WORK/src/x264"
  ./configure --host=x86_64-w64-mingw32 --cross-prefix=x86_64-w64-mingw32- --prefix="$PREFIX" \
    --enable-static --disable-cli --disable-opencl --disable-lavf --disable-swscale
  make -j "$JOBS"
  make install
)
cmake_build libwebp -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
  -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_EXTRAS=OFF \
  -DWEBP_BUILD_FUZZTEST=OFF -DWEBP_USE_THREAD=OFF -DWEBP_LINK_STATIC=ON
(
  cd "$WORK/src/openssl"
  export CC=gcc-posix CXX=g++-posix AR=ar RANLIB=ranlib
  CROSS_COMPILE=x86_64-w64-mingw32- perl Configure mingw64 no-shared no-tests no-module no-zlib no-apps \
    --prefix="$PREFIX" --openssldir="$PREFIX/ssl" --libdir=lib
  make -j "$JOBS"
  make install_sw
)

(
  cd "$WORK/src/ffmpeg"
  ./configure --prefix="$PREFIX" --target-os=mingw32 --arch=x86_64 --enable-cross-compile \
    --cross-prefix=x86_64-w64-mingw32- --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" \
    --pkg-config=pkg-config --pkg-config-flags=--static --disable-autodetect --disable-debug \
    --disable-shared --enable-static --disable-doc --disable-ffplay --enable-gpl --enable-version3 \
    --enable-libx264 --enable-libwebp --enable-libass --enable-libfreetype --enable-libharfbuzz \
    --enable-libfribidi --enable-libfontconfig --enable-openssl --enable-zlib \
    --extra-cflags="$CFLAGS -ffile-prefix-map=$WORK/src/ffmpeg=/ffmpeg" \
    --extra-cxxflags="$CXXFLAGS -ffile-prefix-map=$WORK/src/ffmpeg=/ffmpeg" \
    --extra-ldflags="$LDFLAGS" --extra-libs='-lstdc++ -lpthread' --extra-version=mise1
  make -j "$JOBS"
  make install
)

PKG="$WORK/package/mise-ffmpeg-8.1.3"
SRC="$WORK/source-package/FFmpeg-8.1.3-mise-source"
mkdir -p "$PKG/bin" "$PKG/licenses" "$SRC/sources" "$SRC/build-record"
cp "$PREFIX/bin/ffmpeg.exe" "$PREFIX/bin/ffprobe.exe" "$PKG/bin/"
"$STRIP" "$PKG/bin/ffmpeg.exe" "$PKG/bin/ffprobe.exe"
cp "$WORK/src/ffmpeg/COPYING.GPLv3" "$PKG/LICENSE"
cp "$ROOT/fonts.conf" "$PKG/fonts.conf"
cp "$ROOT/README.md" "$PKG/README.txt"
cp "$ROOT/build.sh" "$ROOT/sources.json" "$ROOT/fonts.conf" "$ROOT/README.md" "$SRC/"
cp "$WORK/downloads/"* "$SRC/sources/"
cp "$WORK/cross.ini" "$WORK/toolchain.cmake" "$SRC/build-record/"
cp "$WORK/src/ffmpeg/ffbuild/config.mak" "$WORK/src/ffmpeg/ffbuild/config.log" "$SRC/build-record/"
dpkg-query -W -f='${binary:Package}\t${Version}\n' > "$SRC/build-record/dpkg-packages.tsv"
"$CC" -v > "$SRC/build-record/compiler.txt" 2>&1
meson --version > "$SRC/build-record/meson.txt"
for name in ffmpeg ffprobe; do
  x86_64-w64-mingw32-objdump -p "$PKG/bin/$name.exe" | grep 'DLL Name:' >> "$SRC/build-record/imports.txt"
done
python3 - "$ROOT" "$WORK" "$PKG" "$SRC" <<'PY'
import hashlib, json, pathlib, shutil, sys
root, work, package, source = map(pathlib.Path, sys.argv[1:])
manifest = json.loads((root / 'sources.json').read_text())
for component in manifest['packages']:
    target = package / 'licenses' / component['name']
    target.mkdir()
    base = work / 'src' / component['name']
    notices = []
    for candidate in base.rglob('*'):
        if not candidate.is_file() or candidate.is_symlink():
            continue
        name = candidate.name.lower()
        if len(candidate.relative_to(base).parts) <= 3 and (name.startswith(('license', 'copying', 'notice', 'copyright')) or name in ['ftl.txt', 'gplv2.txt']):
            relative = candidate.relative_to(base)
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(candidate, destination)
            notices.append(str(relative))
    if not notices:
        raise SystemExit('No license material collected: ' + component['name'])
for pattern in ['gcc-mingw-w64*', 'g++-mingw-w64*', 'mingw-w64*']:
    for folder in pathlib.Path('/usr/share/doc').glob(pattern):
        copyright_file = folder / 'copyright'
        if copyright_file.is_file():
            target = package / 'licenses' / 'toolchain' / folder.name
            target.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(copyright_file, target / 'copyright')
record = {
    'schema': 1,
    'profile': manifest['profile'],
    'ffmpegVersion': manifest['ffmpegVersion'],
    'sourceInputsComplete': True,
    'sourceArchive': 'FFmpeg-8.1.3-mise-source.tar.gz',
    'sourceManifestSha256': hashlib.sha256((root / 'sources.json').read_bytes()).hexdigest(),
    'buildRecipeSha256': hashlib.sha256((root / 'build.sh').read_bytes()).hexdigest(),
    'packages': manifest['packages'],
    'binaries': {name: hashlib.sha256((package / 'bin' / name).read_bytes()).hexdigest() for name in ['ffmpeg.exe', 'ffprobe.exe']},
    'patches': [],
    'systemComponents': 'Unmodified Ubuntu build tools and MinGW/GCC toolchain, including compiler runtime covered by its runtime exception; Windows system DLLs listed in build-record/imports.txt. Toolchain package versions and license notices are included.',
    'bitIdenticalRebuildVerified': False
}
for destination in [package / 'BUILD-INFO.json', source / 'BUILD-INFO.json']:
    destination.write_text(json.dumps(record, indent=2) + '\n')
shutil.copytree(package / 'licenses', source / 'licenses')
for base in [package, source]:
    files = sorted(p for p in base.rglob('*') if p.is_file())
    (base / 'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(base).as_posix() + '\n' for p in files))
PY
find "$PKG" "$SRC" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
(
  cd "$WORK/package"
  find mise-ffmpeg-8.1.3 -type f | sort | zip -X -9 "$DIST/FFmpeg-8.1.3-mise-win64.zip" -@
)
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner -C "$WORK/source-package" \
  -cf - FFmpeg-8.1.3-mise-source | gzip -n > "$DIST/FFmpeg-8.1.3-mise-source.tar.gz"
cp "$PKG/BUILD-INFO.json" "$DIST/BUILD-INFO.json"
(
  cd "$DIST"
  sha256sum FFmpeg-8.1.3-mise-win64.zip FFmpeg-8.1.3-mise-source.tar.gz BUILD-INFO.json > SHA256SUMS.txt
)
printf 'Media distribution prepared at %s\n' "$DIST"

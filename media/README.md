# Mise Windows media runtime

This is a separately executed FFmpeg 8.1.3 GPLv3-or-later distribution, built from the complete, checksum-pinned source inputs in sources.json. It is not linked into Mise. The binary package and its matching source archive must remain available together when distributed.

## Included features

The curated Windows x64 static build includes FFmpeg's internal codecs, formats and filters, x264 H.264, AAC, PNG, WebP, ASS/subtitles, FreeType/HarfBuzz/FriBidi text rendering, Fontconfig/DirectWrite font discovery, zlib and OpenSSL HTTPS. Other optional external codecs from the former Gyan essentials build are not enabled. No private Mise application source, user projects, credentials or assets are included.

The package contains eleven exact upstream source archives without local patches, the complete build recipe, Fontconfig configuration, per-component notices, binary hashes and captured compiler/configuration records. The source archive can be rebuilt without downloading its library source inputs.

## Rebuild

Use Ubuntu 24.04 x64 with build-essential, gcc-mingw-w64-x86-64-posix, g++-mingw-w64-x86-64-posix, mingw-w64-tools, cmake, ninja-build, meson, nasm, pkg-config, python3, curl, git, perl, autoconf, automake, libtool, gettext, gperf, zip, xz-utils, bison and flex. Run bash build.sh from the extracted source distribution. An empty temporary build directory is created automatically. MISE_MEDIA_BUILD_ROOT can select a different empty directory; MISE_MEDIA_JOBS controls parallel compilation. Outputs go into dist alongside the recipe.

The public media-build workflow installs these tools and runs this same recipe. Exact installed toolchain package versions, configure output, cross-compilation settings and imported Windows DLLs are recorded under build-record. Unmodified general-purpose build tools, the MinGW/GCC toolchain and Windows system DLLs are identified separately rather than misrepresented as bundled library sources. Compiler/runtime licensing notices are included; GCC's runtime exception applies to its normally compiled runtime code. No claim of an independently verified bit-identical rebuild is made.

The build downloads sources only when they are absent from the adjacent sources directory, verifies every SHA-256 before extraction, disables dependency auto-discovery and Meson fallback downloads, and does not run third-party test suites. It uses a fixed SOURCE_DATE_EPOCH and removes Windows linker timestamps. It never runs paid generation.

## Windows use

Use bin/ffmpeg.exe and bin/ffprobe.exe. Set FONTCONFIG_FILE to the absolute path of the accompanying fonts.conf and FONTCONFIG_PATH to its containing directory. Font files and caches belong to the existing Windows/user environment; no user fonts are redistributed in this package.

## Licenses and source access

LICENSE is FFmpeg's GPLv3 license. The licenses directory contains the linked components' notices, including x264's GPL license, FreeType's dual-license materials, Fontconfig's permissive notices, FriBidi's LGPL, HarfBuzz's permissive notices, libass's ISC license, WebP's BSD notices, zlib, Expat and OpenSSL's Apache 2.0 license. Full original notices also remain in each source archive.

The binary package names its corresponding source archive in BUILD-INFO.json. Distribute FFmpeg-8.1.3-mise-source.tar.gz from the same stable GitHub release as the Mise installer, at no additional charge. SHA256SUMS.txt protects integrity relative to its distribution metadata, not publisher identity. Keep old source archives available for as long as their binaries remain downloadable. See https://ffmpeg.org/legal.html and https://www.gnu.org/licenses/gpl-3.0.html.

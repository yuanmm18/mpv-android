#!/bin/bash -e

cd "$( dirname "${BASH_SOURCE[0]}" )"
./include/depinfo.sh

清理构建=0
无依赖=
0
响=1
目标=mpv-安卓
架构=armv7l

获取依赖 () {
	变量名="dep_${1//-/_}[*]"
	回显  ${!varname} 
}

加载架构 () {{
	未设置 CC CXX CPATH LIBRARY_PATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH
	未设置 CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

	本地 apilvl=21
	# ndk_triple: 工具链实际上是什么
	# cc_triple: Google 所谓的工具链
如果 [ ] 等于 那么
		导出 ndk后缀=
		导出 ndk_三重=arm-linux-androideabi
		cc_triple=armv7a-linux-androideabi$apilvl
		前缀名=armv7l
	elif [ "$1" == "arm64" ]; then
		导出 ndk后缀=-arm64
		导出 ndk_三重=aarch64-linux-android
cc_triple = $ndk_triple$apilvl
		前缀名=arm64
	elif [ "$1" == "x86" ]; then
		导出 ndk后缀=-x86
		导出 ndk_triple=i686-linux-android
cc_triple = $ndk_triple$apilvl
		前缀名=x86
	elif [ "$1" == "x86_64" ]; then
		导出 ndk后缀=-x64
		导出 ndk_三重=x86_64-linux-android
cc_triple = $ndk_triple$apilvl
		前缀名=x86_64
	否则
		echo "无效的架构" >&2
		退出 1
	输入：fi
	导出 前缀目录="$PWD/prefix/$prefix_name"
	if [ $clang -eq 1 ]; then      
		导出CC=$cc_triple-clang
		export CXX=$cc_triple-clang++
	else
		export CC=$cc_triple-gcc
		export CXX=$cc_triple-g++
	fi
	export LDFLAGS="-Wl,-O1,--icf=safe -Wl,-z,max-page-size=16384"
	export AR=llvm-ar
	export RANLIB=llvm-ranlib
}

setup_prefix () {
	if [ ! -d "$prefix_dir" ]; then
		mkdir -p "$prefix_dir"
		# enforce flat structure (/usr/local -> /)
		ln -s . "$prefix_dir/usr"
		ln -s . "$prefix_dir/local"
	fi

	local cpu_family=${ndk_triple%%-*}
	[ "$cpu_family" == "i686" ] && cpu_family=x86

	if ! command -v pkg-config >/dev/null; then
		echo "未提供pkg-config!"
		返回 1
	输入：fi

	# meson希望提前创建这个文件以便喂食，所以提前创建
	# 还定义：发布版、静态库和运行时禁止下载源代码(!!!)
	猫 >"$prefix_dir/crossfile.tmp" <<CROSSFILE
[内置选项]
构建类型 = '发布版'
默认库 = '静态'
包装模式 = '不下载'
前缀 = '/usr/local'
[二进制文件]
c = '$CC'
cpp = '$CXX'
ar = 'llvm-ar'
nm = 'llvm-nm'
strip = 'llvm-strip'
pkgconfig = 'pkg-config'
pkg-config = 'pkg-config'
[host_machine]
system = 'android'
cpu_family = '$cpu_family'
cpu = '${CC%%-*}'
endian = 'little'
CROSSFILE
	# also avoid rewriting it needlessly
	if cmp -s "$prefix_dir"/crossfile.{tmp,txt}; then
		rm "$prefix_dir/crossfile.tmp"
	else
		mv "$prefix_dir"/crossfile.{tmp,txt}
	fi
}

build () {
	if [ $1 != "mpv-android" ] && [ ! -d deps/$1 ]; then
		printf >&2 '\e[1;31m%s\e[m\n' "Target $1 not found"
		return 1
	fi
	if [ $nodeps -eq 0 ]; then
		printf >&2 '\e[1;34m%s\e[m\n' "Preparing $1..."
		local deps=$(getdeps $1)
		echo >&2 "Dependencies: $deps"
		for dep in $deps; do
			build $dep
		done
	fi
	printf >&2 '\e[1;34m%s\e[m\n' "Building $1..."
	if [ "$1" == "mpv-android" ]; then
		pushd ..
		BUILDSCRIPT=buildscripts/scripts/$1.sh
	else
		pushd deps/$1
		BUILDSCRIPT=../../scripts/$1.sh
	fi
	[ $cleanbuild -eq 1 ] && $BUILDSCRIPT clean
	$BUILDSCRIPT build
	popd
}

usage () {
	printf '%s\n' \
		"Usage: buildall.sh [options] [target]" \
		"Builds the specified target (default: $target)" \
		"-n             Do not build dependencies" \
		"--clean        Clean build dirs before compiling" \
		"--gcc          Use gcc compiler (unsupported!)" \
		"--arch <arch>  Build for specified architecture (default: $arch; supported: armv7l, arm64, x86, x86_64)"
	exit 0
}

while [ $# -gt 0 ]; do
	case "$1" in
		--clean)
		cleanbuild=1
		;;
		-n|--no-deps)
		nodeps=1
		;;
		--gcc)
		clang=0
		;;
		--arch)
		shift
		arch=$1
		;;
		-h|--help)
		usage
		;;
		-*)
		echo "Unknown flag $1" >&2
		exit 1
		;;
		*)
		target=$1
		;;
	esac
	shift
done
# 参数兼容：把 arm64-v8a 映射为 arm64
if [ "$arch" = "arm64-v8a" ]; then
  arch=arm64
elif [ "$arch" = "armeabi-v7a" ]; then
  arch=armv7l
fi
loadarch $arch
setup_prefix
build $target

[ "$target" == "mpv-android" ] && \
	ls -lh ../app/build/outputs/apk/{default,api29}/*/*.apk

exit 0

#!/usr/bin/env bash
# build INSTEAD with emscripten

set -e

export WORKSPACE="/home/mx/Projects/instead_fun/embuild"

# if [ ! -f ./emsdk_env.sh ]; then
# 	echo "Run this script in emsdk directory"
# 	exit 1
# fi
if [ -z "$WORKSPACE" ]; then
	echo "Define WORKSPACE path in $0"
	exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
	echo "Please, create build directory $WORKSPACE"
	exit 1
fi
#. ./emsdk_env.sh

# some general flags
export PATH="$WORKSPACE/bin:$PATH"
export CFLAGS="-g0 -O2"
export CXXFLAGS="$CFLAGS"
export EM_CFLAGS="-Wno-warn-absolute-paths -s LLD_REPORT_UNDEFINED"
export EMMAKEN_CFLAGS="$EM_CFLAGS"
export PKG_CONFIG_PATH="$WORKSPACE/lib/pkgconfig"
export MAKEFLAGS="-j15"

# flags to fake emconfigure and emmake
export CC="emcc"
export CXX="em++"
export LD="$CC"
export LDSHARED="$LD"
export RANLIB="emranlib"
export AR="emar"
export CC_BUILD=cc
export EMCC_DEBUG=1

# Lua
cd $WORKSPACE
rm -rf lua-5.1.5
[ -f lua-5.1.5.tar.gz ] || wget -nv 'https://www.lua.org/ftp/lua-5.1.5.tar.gz'
tar xf lua-5.1.5.tar.gz
cd lua-5.1.5
cat src/luaconf.h | sed -e 's/#define LUA_USE_POPEN//g' -e 's/#define LUA_USE_ULONGJMP//g'>src/luaconf.h.new
mv src/luaconf.h.new src/luaconf.h
#emmake make clean
#emmake make posix CC=emcc AR="emar rcu -s"
#emmake make install INSTALL_TOP=$WORKSPACE 

# libiconv
cd $WORKSPACE
rm -rf libiconv-1.15
[ -f libiconv-1.15.tar.gz ] || wget -nv 'https://ftp.gnu.org/gnu/libiconv/libiconv-1.15.tar.gz'
tar xf libiconv-1.15.tar.gz
cd libiconv-1.15
#emconfigure ./configure --prefix=$WORKSPACE
#emmake make install

# # libmikmod
# cd $WORKSPACE
# rm -rf libmikmod-3.1.12/
# [ -f SDL2_mixer-2.0.1.tar.gz ] || wget -nv https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.1.tar.gz
# tar xf SDL2_mixer-2.0.1.tar.gz
# mv SDL2_mixer-2.0.1/external/libmikmod-3.1.12/ libmikmod-3.1.12/
# cd libmikmod-3.1.12/
# emconfigure ./configure --prefix=$WORKSPACE --disable-shared --enable-static 
# emmake make install SHELL="${SHELL}"


cd $WORKSPACE
[ -d  instead-em-js ] ||  mkdir instead-em-js 
[ -d  instead-em-js/fs ] || mkdir instead-em-js/fs
cp -R instead-em/icon instead-em-js/fs/
cp -R instead-em/stead instead-em-js/fs/
cp -R instead-em/themes instead-em-js/fs/
cp -R instead-em/lang instead-em-js/fs/
cp -R instead-em/games instead-em-js/fs/
#rm -rf instead-em-js/fs/games # without games
find instead-em-js/fs/ \( -name '*.svg' -o -name Makefile -o -name CMakeLists.txt \) -exec rm {} \;

unzip -o -j instead-em/contrib/instead-em.zip -d instead-em-js/
cd instead-em-js

cat <<EOF > post.js
var Module;
FS.mkdir('/appdata');
FS.mount(IDBFS,{},'/appdata');

Module['postRun'].push(function() {
	var argv = []
	var req
	if (typeof window === "object") {
		argv = window.location.search.substr(1).trim().split('&');
		if (!argv[0])
			argv = [];
	}
	var url = argv[0];
	if (!url) {
		FS.syncfs(true, function (error) {
			if (error) {
				console.log("Error while syncing: ", error);
			};
			console.log("Running...");
			Module.ccall('instead_main', 'number');
		});
		return;
	}

	req = new XMLHttpRequest();
	req.open("GET", url, true);
	req.responseType = "arraybuffer";
	console.log("Get: ", url);

	setTimeout(function() {
		var spinnerElement = document.getElementById('spinner');
		spinnerElement.style.display = 'inline-block';
		Module['setStatus']('Downloading data file...');
	}, 3);

	req.onload = function() {
		var basename = function(path) {
			parts = path.split( '/' );
			return parts[parts.length - 1];
		}
		var data = req.response;
		console.log("Data loaded...");
		FS.syncfs(true, function (error) {
			if (error) {
				console.log("Error while syncing: ", error);
			}
			url = basename(url);
			console.log("Writing: ", url);
			FS.writeFile(url, new Int8Array(data), { encoding: 'binary' }, "w");
			console.log("Running...");
			var args = [];
			[ "instead-em", url, "-standalone", "-window", "-resizable", "-mode" ].forEach(function(item) {
				args.push(allocate(intArrayFromString(item), ALLOC_NORMAL));
				args.push(0); args.push(0); args.push(0);
			})
			args = allocate(args, ALLOC_NORMAL);
			setTimeout(function() {
				Module.setStatus('');
				document.getElementById('status').style.display = 'none';
			}, 3);
			window.onclick = function(){ window.focus() };
			Module.ccall('instead_main', 'number', ["number", "number"], [6, args ]);
		});
	}
	req.send(null);
});
EOF

# INSTEAD
echo "INSTEAD"
cd $WORKSPACE
[ -d instead-em ] || git clone https://github.com/instead-hub/instead.git instead-em
cd instead-em
[ -e Rules.make ] || ln -s Rules.standalone Rules.make
cat <<EOF > config.make
EXTRA_CFLAGS+= -DNOMAIN -D_HAVE_ICONV -I${WORKSPACE}/include
SDL_CFLAGS=-I../../include/SDL2
SDL_LFLAGS=
LUA_CFLAGS=
LUA_LFLAGS=
ZLIB_LFLAGS=
EOF
#emmake make clean
#emmake make AR=emar

cd $WORKSPACE
emcc ${WORKSPACE}/instead-em/src/sdl-instead \
	${WORKSPACE}/lib/liblua.a \
	${WORKSPACE}/lib/libiconv.so \
	-s USE_ZLIB=1 \
	-s USE_SDL=2 \
	-s USE_SDL_MIXER=2 \
	-s USE_SDL_TTF=2 \
	-s USE_SDL_IMAGE=2 -s SDL2_IMAGE_FORMATS='["png","jpg","gif"]' \
	-s USE_FREETYPE=1 \
	-s USE_HARFBUZZ=1 \
	-s USE_VORBIS=1 \
	-s INITIAL_MEMORY=167772160 -s ALLOW_MEMORY_GROWTH=1 \
	-s EXPORTED_RUNTIME_METHODS="['ccall']" \
	-s PRECISE_F32=1 \
	-s USE_OGG=1 -s USE_VORBIS=1 -s USE_LIBPNG=1 \
	-s SAFE_HEAP=0 \
	-lidbfs.js \
	--post-js ${WORKSPACE}/instead-em-js/post.js  \
	--memory-init-file 1 \
	--preload-file ${WORKSPACE}/instead-em-js/fs@/ \
	-s QUANTUM_SIZE=4 \
	-s EXPORTED_FUNCTIONS='["_instead_main"]' -o final.html

echo "Happy hacking"
http

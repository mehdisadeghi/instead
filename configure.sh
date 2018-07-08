#!/bin/sh
echo -n "Checking pkg-config..."
if ! pkg-config --version >/dev/null 2>&1; then
	echo "error: no pkg-config in \$PATH."
	exit 1
fi
echo "ok"

echo -n "Checking pkg-config --cflags zlib..."
if ! pkg-config --cflags zlib >/dev/null 2>&1; then
	if [ -f /usr/include/zlib.h ]; then
		echo "not found, but /usr/include/zlib.h exists..."
		zlib_cflags="x"
		zlib_libs=
	else 
		echo "internal"
		zlib_cflags=
		zlib_libs=
	fi
else
	echo "system"
	zlib_cflags="pkg-config --cflags zlib"
	zlib_libs="pkg-config --libs zlib"
fi

echo -n "Checking pkg-config --cflags gtk+-2.0..."
if ! pkg-config --cflags gtk+-2.0 >/dev/null 2>&1; then
	echo "no"
	echo -n "Checking pkg-config --cflags gtk+-3.0..."
	if ! pkg-config --cflags gtk+-3.0 >/dev/null 2>&1; then
		echo "no open file dialog"
		gtk_cflags=
		gtk_libs=
	else
		echo "yes"
		gtk_cflags="pkg-config --cflags gtk+-3.0"
		gtk_libs="pkg-config --libs gtk+-3.0"
	fi
else
	echo "yes"
	gtk_cflags="pkg-config --cflags gtk+-2.0"
	gtk_libs="pkg-config --libs gtk+-2.0"
fi



echo -n "Checking pkg-config --cflags lua[5.1|5.2|51|52|jit]..."
if [ "x$LUA" = "x" ]; then
	lua_ver="lua5.1 lua5.2 lua lua-5.1 lua-5.2 lua51 lua52 luajit"
else
	lua_ver=$LUA
fi

for v in $lua_ver; do
	if pkg-config --cflags "$v" >/dev/null 2>&1; then
		echo "$v"
		lua_cflags="pkg-config --cflags $v"
		lua_libs="pkg-config --libs $v"
		break
	fi
done

if test "x$lua_libs" = "x"; then
	echo "failed: no package lua/lua5.1/lua5.2/lua-5.1/lua-5.2/lua51/lua52"
	echo "Please install lua development package."
	exit 1
fi


echo -n "Checking sdl2-config..."
if ! sdl2-config --version >/dev/null 2>&1; then
	if ! sdl-config --version >/dev/null 2>&1; then
		echo "error: no sdl-config/sdl2-config in \$PATH."
		echo "Please install sdl, sdl_ttf, sdl_mixer and sdl_image development packages."
		exit 1
	fi
	echo "no, using SDL 1.xx"
	sdl_config="sdl-config"
	sdl_libs="-lSDL_ttf -lSDL_mixer -lSDL_image -lm"
else
	echo "ok"
	sdl_config="sdl2-config"
	sdl_libs="-lSDL2_ttf -lSDL2_mixer -lSDL2_image -lm"
fi

echo -n "Checking sdl-config --cflags..."
if ! $sdl_config --cflags  >/dev/null 2>&1; then
	echo "failed."
	exit 1
fi
echo "ok"

ops="$CPPFLAGS $CFLAGS $LDFLAGS"
ops=$ops" "`$lua_cflags`
ops=$ops" "`$lua_libs`

echo -n "Looking for compiler..."
if ! $CC --version >/dev/null 2>&1; then
	if ! cc --version >/dev/null 2>&1; then
		if ! gcc --version >/dev/null 2>&1; then
			echo "cc, gcc, \$(CC) are not valid compilers... Please export CC for valid one...";
			exit 1;
		else
			cc="gcc";	
		fi
	else
		cc="cc"	
	fi
else
	cc=$CC	
fi

cat << EOF >/tmp/sdl-test.c
#include <SDL.h>
#include <SDL_image.h>
#include <SDL_ttf.h>
#include <SDL_mutex.h>
#include <SDL_mixer.h>
int main(int argc, char **argv)
{
	return 0;
}
EOF
echo $cc
echo -n "Checking test build...("
echo -n $cc /tmp/sdl-test.c $ops `$sdl_config --cflags` `$sdl_config --libs` $sdl_libs -o /tmp/sdl-test ")..."
if ! $cc /tmp/sdl-test.c $ops `$sdl_config --cflags` `$sdl_config --libs` $sdl_libs -o /tmp/sdl-test; then
	echo "failed".
	echo "Please sure if these development packages are installed: sdl, sdl_ttf, sdl_mixer, sdl_image."
	rm -f /tmp/sdl-test.c /tmp/sdl-test
	exit 1
fi
echo "ok"
rm -f /tmp/sdl-test.c /tmp/sdl-test

cat << EOF >/tmp/iconv-test.c
#include <iconv.h>
int main(int argc, char **argv)
{
	iconv_open("","");
}
EOF
echo $cc
echo -n "Checking iconv...("
echo -n "$cc /tmp/iconv-test.c -o iconv-test)..."

if $cc /tmp/iconv-test.c -o /tmp/iconv-test >/dev/null 2>&1; then
	CFLAGS="$CFLAGS -D_HAVE_ICONV -DLIBICONV_PLUG" # force FreeBSD to use iconv.h from base
	echo "ok"
elif $cc /tmp/iconv-test.c -liconv -o /tmp/iconv-test  >/dev/null 2>&1; then
	CFLAGS="$CFLAGS -D_HAVE_ICONV"
	LDFLAGS="$LDFLAGS -liconv"
	echo "ok, with -liconv"
elif $cc /tmp/iconv-test.c -I/usr/local/include -L/usr/local/lib -liconv -o /tmp/iconv-test  >/dev/null 2>&1; then
	CFLAGS="$CFLAGS -I/usr/local/include -D_HAVE_ICONV"
	LDFLAGS="$LDFLAGS -L/usr/local/lib -liconv"
	echo "ok, with -liconv and -L/usr/local/lib"
else
	echo -n "failed. Build without iconv.".
fi

rm -f /tmp/iconv-test.c /tmp/iconv-test

if ! make clean >/dev/null 2>&1; then
	echo " * Warning!!! Can not do make clean..."
fi
echo -n "Generating config.make..."
echo "# autamatically generated by configure.sh" >config.make

if [ ! -z "$CFLAGS" ]; then
	echo "EXTRA_CFLAGS+=$CFLAGS" >> config.make
fi

if [ ! -z "$LDFLAGS" ]; then
	echo "EXTRA_LDFLAGS+=$LDFLAGS" >> config.make
fi

if [ ! -z "$gtk_cflags" ]; then
	echo "EXTRA_CFLAGS+=-D_USE_GTK -D_USE_BROWSE" >> config.make
	echo "EXTRA_CFLAGS+=\$(shell $gtk_cflags)" >> config.make
	echo "EXTRA_LDFLAGS+=\$(shell $gtk_libs)" >> config.make
fi
if [ -z "$zlib_cflags" ]; then
	echo "SUBDIRS=src/zlib" >> config.make
	echo "ZLIB_CFLAGS=-Izlib" >> config.make
	echo "ZLIB_LFLAGS=zlib/libz.a" >> config.make
elif [ "$zlib_cflags" = "x" ]; then
	echo "ZLIB_CFLAGS=" >> config.make
	echo "ZLIB_LFLAGS=-lz" >> config.make
else
	echo "ZLIB_CFLAGS=\$(shell $zlib_cflags)" >> config.make
	echo "ZLIB_LFLAGS=\$(shell $zlib_libs)" >> config.make
fi
echo "LUA_CFLAGS=\$(shell $lua_cflags)" >> config.make
echo "LUA_LFLAGS=\$(shell $lua_libs)" >> config.make
echo "SDL_CFLAGS=\$(shell $sdl_config --cflags)" >> config.make
echo "SDL_LFLAGS=\$(shell $sdl_config --libs) $sdl_libs" >> config.make
echo "ok"
if [ "x$PREFIX" = "x" ]; then
	echo -n "Choose installation mode. Standalone(1) or system(2) [1]: "
	read ans
else
	ans="2"
fi

if [ "x$ans" = "x1" -o "x$ans" = "x" ]; then
	echo " * Standalone version"
	rm -f Rules.make
	ln -sf Rules.make.standalone Rules.make
	rm -f sdl-instead
	ln -sf src/sdl-instead sdl-instead
	echo "Ok. We are ready to build. Use these commands:"
	echo "    \$ make"
	echo "    \$ ./sdl-instead"
elif [ "x$ans" = "x2" ]; then
	if [ "x$PREFIX" = "x" ]; then
		echo -n "Enter prefix path [/usr/local]: "
		read ans
	else
		ans="$PREFIX"
	fi

	if [ "x$ans" = "x" ]; then
		prefix="/usr/local"
	else
		prefix="$ans"
	fi
	
	rm -f Rules.make
	ln -s Rules.make.system Rules.make

	echo " * System version with prefix: $prefix"

	echo "PREFIX=$prefix" >> config.make
	echo "BIN=\$(PREFIX)/bin/" >> config.make 
	echo "DATAPATH=\$(PREFIX)/share/instead" >> config.make
	echo "STEADPATH=\$(DATAPATH)/stead" >> config.make
	echo "THEMESPATH=\$(DATAPATH)/themes" >> config.make
	echo "GAMESPATH=\$(DATAPATH)/games" >> config.make
	echo "ICONPATH=\$(PREFIX)/share/pixmaps" >> config.make
	echo "DOCPATH=\$(PREFIX)/share/doc/instead" >> config.make
	echo "LANGPATH=\$(DATAPATH)/lang" >> config.make
	echo "MANPATH=\$(PREFIX)/share/man/man6" >> config.make

	echo "Ok. We are ready to build and install. Use these commands:"
	echo "    \$ make"
	echo "    \$ sudo make install"
	echo "    \$ sdl-instead"
else
	echo "Huh!!! Wrong answer."
	exit 1
fi

echo " Enjoy..."



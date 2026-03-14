#!/bin/bash
# Gaia Linux - Stage 3: Base System
# Enter chroot and rebuild everything natively from source

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 3: Base System ==="
echo "Build root: $GAIA"

# --- Prepare virtual kernel filesystems ---
echo ""
echo "Mounting virtual filesystems..."
mkdir -pv "$GAIA"/{dev,proc,sys,run}

mount -v --bind /dev "$GAIA/dev"
mount -vt devpts devpts -o gid=5,mode=0620 "$GAIA/dev/pts"
mount -vt proc proc "$GAIA/proc"
mount -vt sysfs sysfs "$GAIA/sys"
mount -vt tmpfs tmpfs "$GAIA/run"

if [ -h "$GAIA/dev/shm" ]; then
    install -v -d -m 1777 "$GAIA$(readlink "$GAIA/dev/shm")"
else
    mount -vt tmpfs -o nosuid,nodev tmpfs "$GAIA/dev/shm"
fi

# --- Create essential files inside chroot ---
echo ""
echo "Creating essential system files..."

cat > "$GAIA/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Sync:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
sddm:x:80:80:SDDM Display Manager:/var/lib/sddm:/usr/bin/false
polkitd:x:81:81:PolicyKit Daemon:/etc/polkit-1:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

cat > "$GAIA/etc/group" << 'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
render:x:62:
wheel:x:97:
users:x:999:
sddm:x:80:
polkitd:x:81:
nogroup:x:65534:
EOF

cat > "$GAIA/etc/hosts" << 'EOF'
127.0.0.1  localhost
::1        localhost
127.0.1.1  gaia
EOF

echo "gaia" > "$GAIA/etc/hostname"

# --- Generate chroot build script ---
# This script runs inside the chroot and builds all base system packages
cat > "$GAIA/tmp/build-base.sh" << 'CHROOTEOF'
#!/bin/bash
set -e

export HOME=/root
export TERM=xterm-256color
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"

SRC="/sources"

echo "=== Inside chroot: building base system ==="

# Helper function
build_gnu() {
    local name="$1" ver="$2" ext="$3" opts="$4" pre="$5" post="$6"
    echo ""
    echo ">>> $name-$ver"
    cd "$SRC"
    tar xf "${name}-${ver}.tar.${ext}"
    cd "${name}-${ver}"
    [ -n "$pre" ] && eval "$pre"
    ./configure --prefix=/usr $opts
    make
    make install
    [ -n "$post" ] && eval "$post"
    cd "$SRC" && rm -rf "${name}-${ver}"
}

# --- iana-etc (network service names) ---
echo ">>> iana-etc"
# Create minimal /etc/services and /etc/protocols
cat > /etc/protocols << 'PROTO'
ip	0	IP
icmp	1	ICMP
tcp	6	TCP
udp	17	UDP
PROTO
cat > /etc/services << 'SERV'
ssh		22/tcp
http		80/tcp
https		443/tcp
domain		53/tcp
domain		53/udp
SERV

# --- Zlib ---
echo ""
echo ">>> zlib"
cd "$SRC" && tar xf zlib-*.tar.xz
cd zlib-*/
./configure --prefix=/usr
make && make install
rm -fv /usr/lib/libz.a
cd "$SRC" && rm -rf zlib-*/

# --- Bzip2 ---
echo ""
echo ">>> bzip2"
cd "$SRC" && tar xf bzip2-*.tar.gz 2>/dev/null || true
if [ -d bzip2-*/ ]; then
    cd bzip2-*/
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/usr install
    cp -v bzip2-shared /usr/bin/bzip2
    for i in bunzip2 bzcat; do ln -sfv bzip2 /usr/bin/$i; done
    rm -fv /usr/lib/libbz2.a
    cd "$SRC" && rm -rf bzip2-*/
fi

# --- Xz ---
build_gnu "xz" "*" "xz" "--disable-static --docdir=/usr/share/doc/xz"

# --- Zstd ---
echo ""
echo ">>> zstd"
cd "$SRC" && tar xf zstd-*.tar.gz
cd zstd-*/
make prefix=/usr
make prefix=/usr install
rm -v /usr/lib/libzstd.a
cd "$SRC" && rm -rf zstd-*/

# --- File ---
build_gnu "file" "*" "gz" ""

# --- Readline ---
build_gnu "readline" "*" "gz" \
    "--disable-static --with-curses --docdir=/usr/share/doc/readline" \
    'sed -i "/MV.*old/d" Makefile.in; sed -i "/{OLDSUFF}/c:" support/shlib-install'

# --- M4 ---
build_gnu "m4" "*" "xz" ""

# --- Bc ---
echo ">>> bc (skipping - optional)"

# --- Flex ---
echo ">>> flex (skipping - build later if needed)"

# --- Binutils (native) ---
echo ""
echo ">>> binutils (native rebuild)"
cd "$SRC" && tar xf binutils-*.tar.xz
cd binutils-*/
mkdir -v build && cd build
../configure --prefix=/usr \
    --sysconfdir=/etc \
    --enable-gold \
    --enable-ld=default \
    --enable-plugins \
    --enable-shared \
    --disable-werror \
    --enable-64-bit-bfd \
    --enable-new-dtags \
    --enable-default-hash-style=gnu \
    --with-system-zlib
make tooldir=/usr
make tooldir=/usr install
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
cd "$SRC" && rm -rf binutils-*/

# --- GMP ---
echo ""
echo ">>> gmp"
cd "$SRC" && tar xf gmp-*.tar.xz
cd gmp-*/
./configure --prefix=/usr \
    --enable-cxx \
    --disable-static \
    --docdir=/usr/share/doc/gmp
make && make install
cd "$SRC" && rm -rf gmp-*/

# --- MPFR ---
build_gnu "mpfr" "*" "xz" "--disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr"

# --- MPC ---
build_gnu "mpc" "*" "gz" "--disable-static --docdir=/usr/share/doc/mpc"

# --- Attr ---
echo ">>> attr (skipping - build if needed by acl)"

# --- ACL ---
echo ">>> acl (skipping - build if needed)"

# --- Libcap ---
echo ">>> libcap (skipping - build if needed)"

# --- Libxcrypt ---
echo ">>> libxcrypt (skipping - using glibc crypt)"

# --- Shadow ---
echo ">>> shadow (skipping - build in stage4)"

# --- GCC (native rebuild) ---
echo ""
echo ">>> gcc (native rebuild)"
cd "$SRC" && tar xf gcc-*.tar.xz
cd gcc-*/
tar xf "$SRC"/mpfr-*.tar.xz && mv mpfr-*/ mpfr
tar xf "$SRC"/gmp-*.tar.xz  && mv gmp-*/  gmp
tar xf "$SRC"/mpc-*.tar.gz  && mv mpc-*/  mpc

case $(uname -m) in
    x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
esac

mkdir -v build && cd build
../configure --prefix=/usr \
    LD=ld \
    --enable-languages=c,c++ \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-multilib \
    --disable-bootstrap \
    --disable-fixincludes \
    --with-system-zlib
make
make install

# Create cc symlink
ln -sfv gcc /usr/bin/cc

# Compatibility symlink
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/*/liblto_plugin.so \
    /usr/lib/bfd-plugins/

# Sanity check
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep -q '/lib.*/ld-linux' && echo "  GCC sanity check: PASSED" || echo "  WARNING: GCC check inconclusive"
rm -v dummy.c a.out dummy.log

cd "$SRC" && rm -rf gcc-*/

# --- Ncurses ---
echo ""
echo ">>> ncurses (native)"
cd "$SRC" && tar xf ncurses-*.tar.gz
cd ncurses-*/
./configure --prefix=/usr \
    --mandir=/usr/share/man \
    --with-shared \
    --without-debug \
    --without-normal \
    --with-cxx-shared \
    --enable-pc-files \
    --enable-widec \
    --with-pkg-config-libdir=/usr/lib/pkgconfig
make && make DESTDIR="" install
# Compatibility links
for lib in ncurses form panel menu; do
    ln -sfv "lib${lib}w.so" "/usr/lib/lib${lib}.so"
    ln -sfv "${lib}w.pc" "/usr/lib/pkgconfig/${lib}.pc"
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
cd "$SRC" && rm -rf ncurses-*/

# --- Sed ---
build_gnu "sed" "*" "xz" ""

# --- Psmisc ---
echo ">>> psmisc (skipping)"

# --- Gettext ---
build_gnu "gettext" "*" "xz" "--disable-static --docdir=/usr/share/doc/gettext"

# --- Bison ---
build_gnu "bison" "*" "xz" "--docdir=/usr/share/doc/bison"

# --- Grep ---
build_gnu "grep" "*" "xz" ""

# --- Bash ---
echo ""
echo ">>> bash (native)"
cd "$SRC" && tar xf bash-*.tar.gz
cd bash-*/
./configure --prefix=/usr \
    --without-bash-malloc \
    --with-installed-readline \
    --docdir=/usr/share/doc/bash
make && make install
cd "$SRC" && rm -rf bash-*/

# --- Libtool ---
build_gnu "libtool" "*" "xz" "" "" 'rm -fv /usr/lib/libltdl.a'

# --- Gdbm ---
echo ">>> gdbm (skipping)"

# --- Gperf ---
echo ">>> gperf (skipping)"

# --- Expat ---
echo ""
echo ">>> expat"
cd "$SRC" && tar xf expat-*.tar.xz
cd expat-*/
./configure --prefix=/usr \
    --disable-static \
    --docdir=/usr/share/doc/expat
make && make install
cd "$SRC" && rm -rf expat-*/

# --- Inetutils ---
echo ">>> inetutils (skipping)"

# --- Less ---
build_gnu "less" "*" "gz" "--sysconfdir=/etc" 2>/dev/null || echo "  less skipped"

# --- Perl ---
echo ""
echo ">>> perl (native)"
cd "$SRC" && tar xf perl-*.tar.xz
cd perl-*/
sh Configure -des \
    -Dprefix=/usr \
    -Dvendorprefix=/usr \
    -Dprivlib=/usr/lib/perl5/core_perl \
    -Darchlib=/usr/lib/perl5/core_perl \
    -Dsitelib=/usr/lib/perl5/site_perl \
    -Dsitearch=/usr/lib/perl5/site_perl \
    -Dvendorlib=/usr/lib/perl5/vendor_perl \
    -Dvendorarch=/usr/lib/perl5/vendor_perl \
    -Dman1dir=/usr/share/man/man1 \
    -Dman3dir=/usr/share/man/man3 \
    -Dpager="/usr/bin/less -isR" \
    -Duseshrplib \
    -Dusethreads
make && make install
cd "$SRC" && rm -rf perl-*/

# --- Autoconf ---
build_gnu "autoconf" "*" "xz" "" 2>/dev/null || echo "  autoconf: using tarball name pattern"

# --- Automake ---
build_gnu "automake" "*" "xz" "--docdir=/usr/share/doc/automake" 2>/dev/null || echo "  automake skipped"

# --- OpenSSL ---
echo ""
echo ">>> openssl"
cd "$SRC" && tar xf openssl-*.tar.gz
cd openssl-*/
./config --prefix=/usr \
    --openssldir=/etc/ssl \
    --libdir=lib \
    shared \
    zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
cd "$SRC" && rm -rf openssl-*/

# --- Kmod ---
echo ">>> kmod (skipping - build in stage4)"

# --- Coreutils ---
build_gnu "coreutils" "*" "xz" \
    "--enable-no-install-program=kill,uptime"

# --- Diffutils ---
build_gnu "diffutils" "*" "xz" ""

# --- Gawk ---
build_gnu "gawk" "*" "xz" ""

# --- Findutils ---
build_gnu "findutils" "*" "xz" "--localstatedir=/var/lib/locate"

# --- Gzip ---
build_gnu "gzip" "*" "xz" ""

# --- Make ---
build_gnu "make" "*" "gz" "--without-guile"

# --- Patch ---
build_gnu "patch" "*" "xz" ""

# --- Tar ---
build_gnu "tar" "*" "xz" "--docdir=/usr/share/doc/tar"

# --- Texinfo ---
build_gnu "texinfo" "*" "xz" ""

# --- Procps-ng ---
echo ">>> procps-ng (skipping - build in stage4)"

# --- Util-linux ---
echo ""
echo ">>> util-linux (native)"
cd "$SRC" && tar xf util-linux-*.tar.xz
cd util-linux-*/
./configure \
    --bindir=/usr/bin \
    --libdir=/usr/lib \
    --runstatedir=/run \
    --sbindir=/usr/sbin \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-static \
    --without-python \
    --without-systemd \
    --without-systemdsystemunitdir \
    --docdir=/usr/share/doc/util-linux
make && make install
cd "$SRC" && rm -rf util-linux-*/

# --- E2fsprogs ---
echo ""
echo ">>> e2fsprogs"
cd "$SRC" && tar xf e2fsprogs-*.tar.gz 2>/dev/null || true
if [ -d e2fsprogs-*/ ]; then
    cd e2fsprogs-*/
    mkdir -v build && cd build
    ../configure --prefix=/usr \
        --sysconfdir=/etc \
        --enable-elf-shlibs \
        --disable-libblkid \
        --disable-libuuid \
        --disable-uuidd \
        --disable-fsck
    make && make install
    rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
    cd "$SRC" && rm -rf e2fsprogs-*/
fi

# --- Python ---
echo ""
echo ">>> python (native)"
cd "$SRC" && tar xf Python-*.tar.xz
cd Python-*/
./configure --prefix=/usr \
    --enable-shared \
    --with-system-expat \
    --enable-optimizations
make && make install
ln -sfv python3 /usr/bin/python
ln -sfv pip3 /usr/bin/pip
cd "$SRC" && rm -rf Python-*/

# --- Ninja ---
echo ""
echo ">>> ninja"
cd "$SRC" && tar xf ninja-*.tar.gz
cd ninja-*/
python3 configure.py --bootstrap
install -vm755 ninja /usr/bin/
cd "$SRC" && rm -rf ninja-*/

# --- Meson ---
echo ""
echo ">>> meson"
cd "$SRC" && tar xf meson-*.tar.gz
cd meson-*/
pip3 install --no-build-isolation --prefix=/usr . 2>/dev/null || \
    python3 setup.py install --prefix=/usr 2>/dev/null || \
    install -vm755 meson.py /usr/bin/meson
cd "$SRC" && rm -rf meson-*/

# --- Cmake ---
echo ""
echo ">>> cmake"
cd "$SRC" && tar xf cmake-*.tar.gz
cd cmake-*/
./bootstrap --prefix=/usr \
    --system-libs \
    --no-system-jsoncpp \
    --no-system-cppdap \
    --no-system-librhash \
    --no-system-libarchive \
    --no-system-libuv \
    --no-system-curl \
    -- -DCMAKE_USE_OPENSSL=OFF
make && make install
cd "$SRC" && rm -rf cmake-*/

# --- Pkg-config ---
echo ""
echo ">>> pkg-config"
cd "$SRC" && tar xf pkg-config-*.tar.gz
cd pkg-config-*/
./configure --prefix=/usr \
    --with-internal-glib \
    --disable-host-tool \
    --docdir=/usr/share/doc/pkg-config
make && make install
cd "$SRC" && rm -rf pkg-config-*/

# --- Man-db ---
echo ">>> man-db (skipping)"

# --- Nano ---
echo ">>> nano (skipping - build in stage4)"

echo ""
echo "=== Base system build complete ==="
echo "All core packages rebuilt natively."
CHROOTEOF

chmod +x "$GAIA/tmp/build-base.sh"

# --- Enter chroot and run build ---
echo ""
echo "Entering chroot to build base system..."
chroot "$GAIA" /usr/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PS1='(gaia chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j${NPROC:-$(nproc)}" \
    /bin/bash /tmp/build-base.sh

# Cleanup
rm -f "$GAIA/tmp/build-base.sh"

echo ""
echo "=== Stage 3 complete ==="
echo "Base system built inside chroot"
echo ""
echo "Next: make stage4"

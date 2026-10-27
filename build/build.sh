#!/bin/bash
# Builds patched Webtatic php56w 5.6.40 RPMs for EL7. Run inside an oraclelinux:7 container.
set -euo pipefail

TARBALL_URL=https://www.php.net/distributions/php-5.6.40.tar.bz2
TARBALL_SHA256=ffd025d34623553ab2f7fd8fb21d0c9e6f9fa30dc565ca03a1d7b763023fba00

echo "== Installing build tools"
yum -y -q install yum-utils rpm-build make gcc gcc-c++ redhat-rpm-config tar patch bzip2 cpio curl
yum-config-manager -q --enable ol7_optional_latest >/dev/null
printf "%s\n" "[epel-archive]" "name=EPEL 7 (Fedora archive)" "baseurl=https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/" "enabled=1" "gpgcheck=1" "gpgkey=https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7" > /etc/yum.repos.d/epel-archive.repo

echo "== Preparing the build tree with Webtatic's recipe"
mkdir -p /root/rpmbuild/{SOURCES,SPECS}
cp /repo/webtatic/* /root/rpmbuild/SOURCES/
mv /root/rpmbuild/SOURCES/php56.spec /root/rpmbuild/SPECS/php56.spec

echo "== Downloading and checking the PHP 5.6.40 source"
cd /root/rpmbuild/SOURCES
curl -fsSL -o php-5.6.40.tar.bz2 "$TARBALL_URL"
echo "$TARBALL_SHA256  php-5.6.40.tar.bz2" | sha256sum -c -

echo "== Adding our patch to the build recipe"
cp /repo/patches/php-5.6.40-php2shell.patch /root/rpmbuild/SOURCES/
cd /root/rpmbuild/SPECS
sed -i 's/^Release: 1%{?rcver:.%{rcver}}%{?dist}$/Release: 1%{?rcver:.%{rcver}}%{?dist}.hardened.1/' php56.spec
sed -i '/^Patch49: /a Patch9001: php-5.6.40-php2shell.patch' php56.spec
sed -i '/^%patch49 /a %patch9001 -p1 -b .php2shell' php56.spec
grep -n 'hardened\.1\|9001' php56.spec

echo "== Installing PHP's build dependencies"
yum-builddep -y -q php56.spec

echo "== Building (this takes a while)"
rpmbuild -ba --nocheck --define 'dist .w7' --define "_smp_mflags -j$(nproc)" php56.spec

mkdir -p /repo/out/rpms
cp /root/rpmbuild/RPMS/x86_64/*.rpm /repo/out/rpms/
(cd /repo/out/rpms && sha256sum -- *.rpm > SHA256SUMS)
echo "== Done. RPMs are in out/rpms"
ls /repo/out/rpms

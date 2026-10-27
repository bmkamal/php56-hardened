# php56-hardened

Hardened build of the Webtatic PHP 5.6.40 packages (`php56w-*-5.6.40-1.w7`) for
RHEL/CentOS 7, with a port of PHP's official fix for PHP2Shell (CVE-2026-109618,
CVE-2026-109619).

PHP has not released a fix for PHP 5.6, and the Webtatic repository has been offline
since 2019. This repository builds the same php56w packages from the official PHP 5.6.40
source and Webtatic's own build recipe, with one added patch. It records every input,
change and test, so the result can be checked and rebuilt independently.

The packages are labelled `5.6.40-1.w7.hardened.1` and install as an upgrade over
`5.6.40-1.w7`. The PHP version stays 5.6.40.

This is a stopgap until the applications move to a supported PHP version. It fixes
PHP2Shell only. PHP 5.6 has had no security fixes since January 2019.

## Where to start

| If you want to... | Read |
| --- | --- |
| Install on a server | [install/INSTALL.md](install/INSTALL.md) (single-file installer) |
| Install step by step without the installer | [install/INSTALL-MANUAL.md](install/INSTALL-MANUAL.md) |
| Check a server after installing | [install/verify.sh](install/verify.sh) |
| See every code change, why it was made and how it compares with PHP's official fix | [docs/CHANGES.md](docs/CHANGES.md) |
| Check where every build input comes from, with checksums | [docs/PROVENANCE.md](docs/PROVENANCE.md) |
| Read the patch itself | [patches/php-5.6.40-php2shell.patch](patches/php-5.6.40-php2shell.patch) |
| See the official fix it ports | [php-src commit 712e60f9](https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2) |
| See the test results | [docs/INSTALL-PRACTICE.md](docs/INSTALL-PRACTICE.md), [docs/INSTALLER-TEST.md](docs/INSTALLER-TEST.md) |

## What's in the repository

| Folder | Contents |
| --- | --- |
| `patches/` | The fix: one patch file changing 10 C source files |
| `webtatic/` | Webtatic's php56w build recipe (commit `d9df9fb`), unchanged |
| `build/` | `build.sh` (patched packages), `build-stock.sh` (unpatched baseline), `make-installer.sh` (single-file installer) |
| `docker/` | Two test containers: the unpatched baseline and the patched build |
| `tests/` | Test settings, test pages and `demo.sh`, which compares the two containers |
| `install/` | Install runbooks, the installer script and the read-only check script |
| `docs/` | Change register, provenance record and test results |
| `releases/` | Checksums of every released package and installer |

Built packages and installers (`out/`) are not stored in Git. Each release records their
checksums in `releases/`.

## How the fix was put together

PHP's official fix is for PHP 7.4. The starting point was an independent, unofficial
open-source port of that fix to PHP 5.4 (third party). It was reviewed line by line
against the official fix and applied to PHP 5.6.40; two changes needed adapting by hand
for 5.6 (C02 and C14 in [docs/CHANGES.md](docs/CHANGES.md)). The work was put together
with the help of AI (Claude), and every change is listed in the change register with a
link to the matching lines of the official fix.

## Rebuild it yourself

Needs Docker, and internet access to Docker Hub, php.net, Oracle's yum servers and the
Fedora EPEL archive. On an Apple Silicon Mac the build runs under x86 emulation and takes
about an hour; an x86 Linux machine is much faster. From the repository folder:

    docker run --rm --platform linux/amd64 -v "$PWD:/repo" oraclelinux:7 bash /repo/build/build.sh 2>&1 | tee build.log
    docker run --rm --platform linux/amd64 -v "$PWD:/repo" oraclelinux:7 bash /repo/build/build-stock.sh 2>&1 | tee build-stock.log

`build.sh` downloads PHP 5.6.40 from php.net and checks its SHA-256, makes three edits to
Webtatic's build recipe (listed in [docs/PROVENANCE.md](docs/PROVENANCE.md)), and builds
the patched packages into `out/rpms`. The build log shows `Patch #9001` applied to
exactly 10 files. `build-stock.sh` builds the same recipe without the patch into
`out/rpms-stock`, for testing and rollback.

To pin the exact build image used for the releases, replace `oraclelinux:7` with
`oraclelinux:7@sha256:767c93c07b1fa621ae56d1f5f090e8c0dce7eb452e7dda1e74bbe7546504d63f`.

### A rebuild won't be byte-for-byte identical

RPM packages record when and where they were built, and PHP records its build date. A
rebuild contains the same code, but its checksums won't match the ones in `releases/`.
`build/make-installer.sh` only accepts packages whose checksums match `releases/`, so it
will refuse a rebuild. That is deliberate: a released installer can only contain the
exact packages that were tested.

### Compare a rebuild with a release

To confirm a rebuild matches a released installer (same packages, same files in each
package, fix present in both), put the installer in the repository folder and run:

    docker run --rm --platform linux/amd64 -v "$PWD:/repo" oraclelinux:7 bash -c '
      yum -y -q install cpio diffutils >/dev/null
      bash /repo/php56-hardened-1.0.0.run --extract /tmp/rel >/dev/null || exit 1
      cd /repo/out/rpms
      for f in *.x86_64.rpm; do
        case "$f" in *debuginfo*) continue ;; esac
        r=/tmp/rel/php56-hardened/hardened/$f
        [ -f "$r" ] || { echo "ONLY IN REBUILD: $f"; continue; }
        diff <(rpm -qlp "$f") <(rpm -qlp "$r") >/dev/null && echo "same files: $f" || echo "DIFFERENT FILES: $f"
      done
      for d in /repo/out/rpms /tmp/rel/php56-hardened/hardened; do
        rpm2cpio $d/php56w-5.6.40-*.x86_64.rpm | cpio -i --to-stdout ./usr/lib64/httpd/modules/libphp5.so 2>/dev/null \
          | grep -qa max_multipart_body_parts && echo "fix present: $d" || echo "FIX MISSING: $d"
      done'

Every package should say `same files`, and both lines should say `fix present`.

### Build your own installer

Only if you want to install your own rebuild instead of a released installer. This
replaces the recorded checksums with your build's, so it becomes a new release that needs
its own testing:

    (cd out/rpms && shasum -a 256 *.rpm) > releases/SHA256SUMS-hardened.txt
    (cd out/rpms-stock && shasum -a 256 *.rpm) > releases/SHA256SUMS-stock.txt
    bash build/make-installer.sh 1.0.0

(On Linux, use `sha256sum` instead of `shasum -a 256`.) The installer is written to `out/installer/`, and its checksum to `releases/`.

## Test it yourself

After both builds:

    docker build --platform linux/amd64 -t php56-stock -f docker/stock/Dockerfile .
    docker build --platform linux/amd64 -t php56-patched -f docker/patched/Dockerfile .
    docker run -d --platform linux/amd64 --name php-stock -p 8081:80 php56-stock
    docker run -d --platform linux/amd64 --name php-patched -p 8082:80 php56-patched
    bash tests/demo.sh

`demo.sh` sends the same requests to both containers. The unpatched build behaves the
old, vulnerable way and the patched build the fixed way. (Some test headings mention
PHP 5.4, because the script was first written for that version.)

## Releases

| Tag | What | SHA-256 |
| --- | --- | --- |
| `v1.0.0-staging` | `php56-hardened-1.0.0-staging.tar.gz` (packages, manual runbook, check script) | [releases/php56-hardened-1.0.0-staging.tar.gz.sha256](releases/php56-hardened-1.0.0-staging.tar.gz.sha256) |
| `v1.0.0` | `php56-hardened-1.0.0.run` (single-file installer) | `c16662c2a7a64672743d50b16bf9d6c575e00dbfb3c40ec932973e9068f3e9c4` |

The packages aren't GPG-signed. Their integrity rests on these checksums, which should
reach whoever installs them separately from the files themselves.

## Known gap

PHP's official fix also changes `substring_conf()` in `main/rfc1867.c` from `int` to
`size_t`. This patch doesn't include it (N01 in the change register). The risk is low,
because `post_max_size` limits request size; it is planned for a later release.

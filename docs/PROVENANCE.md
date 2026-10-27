# Provenance: where every input to the build comes from

## Inputs

| Input | Source | Check |
| --- | --- | --- |
| PHP source | https://www.php.net/distributions/php-5.6.40.tar.bz2 | SHA-256 `ffd025d34623553ab2f7fd8fb21d0c9e6f9fa30dc565ca03a1d7b763023fba00` (php.net's published value), checked automatically by `build/build.sh` |
| Packaging recipe | Webtatic php56w recipe, https://github.com/webtatic-rpms/php56w commit `d9df9fb` ("update to php-5.6.40"), copied unchanged into `webtatic/` | Git commit hash |
| Patch | `patches/php-5.6.40-php2shell.patch` | SHA-256 `63883f9af0acbe4dbfea618daaee5eff7f5dcd8e43b29dbaec685db5e3ec4541`, 387 lines |
| Official fix it ports | https://github.com/php/php-src commit `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2` | Commit hash |
| Build environment | Docker image `oraclelinux:7` | Digest `sha256:767c93c07b1fa621ae56d1f5f090e8c0dce7eb452e7dda1e74bbe7546504d63f` |
| Build dependencies | Oracle Linux 7 repositories (`ol7_latest`, `ol7_optional_latest`) and the EPEL 7 archive (https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/) | Package signatures checked by yum (Oracle and Fedora EPEL keys) |
| Build script | `build/build.sh` | SHA-256 recorded with each release |

## Changes to Webtatic's build recipe

`build/build.sh` makes exactly three edits to `php56.spec`, and nothing else:

1. `Release: 1%{?rcver:.%{rcver}}%{?dist}` gets `.hardened.1` appended, so the packages are
   labelled `5.6.40-1.w7.hardened.1` and install as an upgrade over `5.6.40-1.w7`.
2. `Patch9001: php-5.6.40-php2shell.patch` is added after Webtatic's last patch (`Patch49`).
3. `%patch9001 -p1 -b .php2shell` is added after `%patch49`, so the fix is applied after
   all of Webtatic's packaging patches.

`build/build-stock.sh` builds the same recipe without these edits, as an unpatched
baseline for side-by-side testing.

## Build results

| Item | Value |
| --- | --- |
| Patch applied | 10 files, no fuzz, no offsets (build log, `Patch #9001`) |
| Packages | 33 RPMs, `php56w-*-5.6.40-1.w7.hardened.1.x86_64` |
| RPM checksums | `releases/<version>/SHA256SUMS` |
| Test results | Recorded with each release |

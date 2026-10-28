# Installer tests

## php56-hardened-1.0.1.run (current release)

Date: 28 October 2026
Installer: php56-hardened-1.0.1.run, SHA-256
a89206219d6c7187c0262f76ab73ffe519d399c59349afd9f3bc3dde2d7575d1 (101 MB; 33 hardened
and 33 rollback packages including debuginfo, each matching releases/SHA256SUMS-*.txt)
Server: fresh Oracle Linux 7.9 container (oraclelinux:7, linux/amd64), Apache 2.4.6 with
mod_php, set up with the same 15 stock php56w packages as a real D7 pre-production server
(RMG51WEB010PPD): php56w, -cli, -common, -debuginfo, -devel, -gd, -mbstring, -mcrypt,
-mysql, -opcache, -pdo, -process, -pspell, -soap, -xml (5.6.40-1.w7).

Changes from 1.0.0: bundles the debuginfo packages (1.0.0 stopped on servers with
php56w-debuginfo installed); the post-install check ignores PHP start-up warnings that
were already present before the install; the check also covers libphp5-zts.so and
php-cgi.

| # | Test | Command | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | Dry run | `--dry-run` | DRY RUN OK, 15 packages planned, nothing changed, exit 0 | Pass |
| 2 | Install | `--yes --url http://localhost/ok.php` | DONE, check RESULT: OK, page HTTP 200, exit 0; php56w and debuginfo both hardened | Pass |
| 3 | Run again | `--yes` | "already installed", check RESULT: OK, exit 0 | Pass |
| 4 | Rollback | `--rollback --yes` | ROLLED BACK to 5.6.40-1.w7 (debuginfo too), Apache running, exit 0 | Pass |
| 5 | Forced failure | `--yes --url http://localhost/fail.php` (page returns 500) | install, smoke test fails, automatic rollback, exit 2 | Pass |
| 6 | Tampered copy | one byte changed, `--check` | STOPPED before running anything, exit 1 | Pass |
| 7 | Reinstall | `--yes --url http://localhost/ok.php` | DONE, exit 0 | Pass |

Checked on the real server (read-only): the add-ons there (php56w-pecl-imagick,
-memcache, -xdebug) require only `php(api) = 20131106-64` and `php(zend-abi) =
20131226-64`, which the hardened packages provide unchanged; appdynamics-php-agent has no
PHP package requirement; `php -v` prints no start-up warnings.

Logic tests against stand-in commands also covered: refusal when the test transaction
fails, when yum fails, when Apache isn't running, when an installed php56w package has no
replacement, and when there's no terminal to confirm on and --yes wasn't given; automatic
rollback on new PHP start-up errors; a start-up warning that existed before the install
not causing a rollback; and the build refusing a package whose checksum doesn't match the
tested one.

## php56-hardened-1.0.0.run (superseded)

Installer SHA-256 c16662c2a7a64672743d50b16bf9d6c575e00dbfb3c40ec932973e9068f3e9c4
(32 MB, debuginfo not bundled). Passed the same seven tests on a container with nine
php56w packages (php56w, -cli, -common, -gd, -mbstring, -mysqlnd, -opcache, -pdo, -xml).
Superseded because it stops safely, without changing anything, on servers that have
php56w-debuginfo installed.

# Installer test: php56-hardened-1.0.0.run

Date: 27 October 2026
Installer: php56-hardened-1.0.0.run, SHA-256
c16662c2a7a64672743d50b16bf9d6c575e00dbfb3c40ec932973e9068f3e9c4 (32 MB; 32 hardened
and 32 rollback packages, each matching releases/SHA256SUMS-*.txt)
Server: fresh Oracle Linux 7.9 container (oraclelinux:7, linux/amd64), Apache 2.4.6
with mod_php, stock php56w-5.6.40-1.w7 packages (php56w, -cli, -common, -gd,
-mbstring, -mysqlnd, -opcache, -pdo, -xml), as on D6/D7.

| # | Test | Command | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | Dry run | `--dry-run` | DRY RUN OK, nothing changed, exit 0 | Pass |
| 2 | Install | `--yes --url http://localhost/ok.php` | DONE, check RESULT: OK, page HTTP 200, exit 0 | Pass |
| 3 | Run again | `--yes` | "already installed", check RESULT: OK, exit 0 | Pass |
| 4 | Rollback | `--rollback --yes` | ROLLED BACK to 5.6.40-1.w7, Apache running, exit 0 | Pass |
| 5 | Forced failure | `--yes --url http://localhost/fail.php` (page returns 500) | install, smoke test fails, automatic rollback, exit 2 | Pass |
| 6 | Tampered copy | one byte changed, `--check` | STOPPED before running anything, exit 1 | Pass |
| 7 | Reinstall | `--yes --url http://localhost/ok.php` | DONE, exit 0 | Pass |

Earlier logic tests against stand-in commands also covered: refusal when the test
transaction fails (e.g. a PECL add-on dependency), when yum fails, when Apache
isn't running, when an installed php56w package has no replacement, and when
there's no terminal to confirm on and --yes wasn't given; automatic rollback when
PHP reports start-up errors; and the build refusing a package whose checksum
doesn't match the tested one.

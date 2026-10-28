# Install php56-hardened 1.0.1

Fix for PHP2Shell (CVE-2026-109618, CVE-2026-109619) on RHEL/CentOS 7 servers
running the Webtatic PHP 5.6.40 packages (php56w-*-5.6.40-1.w7) with Apache
mod_php. The PHP version stays 5.6.40; the package release changes to
1.w7.hardened.1.

Everything is in one file, `php56-hardened-1.0.1.run`. Its SHA-256 checksum is
sent separately from the file.

Restarting Apache causes a short outage, so install in an agreed change window,
on QT before production. Run every command as root (sudo -i).

Order of work:

1. Dry run on **every** D6 and D7 server, production included (it changes
   nothing), and send the output back.
2. Install on QT, smoke test, independent security test.
3. Production, in an approved change window, one server at a time.

## 1. Get the file and check it

Download it on the server, if it can reach GitHub:

    cd /root
    curl -fLO https://github.com/bmkamal/php56-hardened/releases/download/v1.0.1/php56-hardened-1.0.1.run

Or copy it to /root from wherever you were given it. Then:

    sha256sum php56-hardened-1.0.1.run      # must match the checksum you were sent

It must be `a89206219d6c7187c0262f76ab73ffe519d399c59349afd9f3bc3dde2d7575d1`.
If it doesn't match, stop: don't run the file.

## 2. Dry run (changes nothing)

    bash php56-hardened-1.0.1.run --dry-run

It must end with `DRY RUN OK`. It checks the server is RHEL/CentOS 7 on
php56w-5.6.40-1.w7, that Apache is running, that every installed php56w package
has a replacement, and runs a test transaction. If it says STOPPED, nothing was
changed: send the output to the build owner.

## 3. Install

If the server is a VM, take a snapshot first. Then:

    bash php56-hardened-1.0.1.run --url http://localhost/

`--url` is optional but recommended: a page on this server that should answer
normally. Use `http://localhost/` if the Drupal site is the server's default
site. If the server hosts several sites, use the site's own hostname, but only
if it resolves to this server (check `/etc/hosts`), not to a load balancer that
could send the request to a different server.

The installer shows its plan and asks you to type `yes`. Then it:

1. backs up the package list, /etc/php.ini, /etc/php.d and Apache's php.conf to
   /root/php56-hardened-backup-<date-time>/
2. replaces the installed php56w packages with the hardened ones, offline
   (add-ons such as php56w-pecl-* and php56w-pear are left as they are)
3. adds /etc/php.d/zz-php2shell.ini, which switches session upload progress off
   as an extra layer (Drupal 6 and 7 don't use this PHP feature)
4. tests Apache's config and restarts Apache (and php-fpm, if running)
5. runs the built-in check and requests the URL

If step 4 or 5 fails, it **rolls back automatically** and says ROLLED BACK.

It must end with `DONE`. WARN lines (for example memory_limit = -1, or Xdebug
loaded) aren't failures but should be reported. Then run the application smoke
test: home page, log in, browse, edit content, upload a file, run cron.

Exit codes: 0 done, 1 stopped before changing anything, 2 install failed and was
rolled back, 3 rollback failed (manual action needed). The full log is in
/var/log/php56-hardened.log.

## What to send back

For each server, send the build owner:

- the dry-run output (step 2)
- the install output (step 3), or `/var/log/php56-hardened.log`, which holds
  every run
- the smoke test result, and any WARN lines

## Check at any time (changes nothing)

    bash php56-hardened-1.0.1.run --check

Every line must say PASS and the last line `RESULT: OK`.

## Rollback

    bash php56-hardened-1.0.1.run --rollback

This puts back unpatched php56w-5.6.40-1.w7 packages, removes
zz-php2shell.ini and restarts Apache. The Webtatic repository has been offline
since 2019, so the rollback packages are built from the same Webtatic recipe and
PHP source, without the patch. Restoring the VM snapshot is also a valid
rollback.

## Inspecting the contents

    bash php56-hardened-1.0.1.run --extract /tmp/inspect

Unpacks the packages, checksums and check script without installing anything.
The manual, step-by-step method is in INSTALL-MANUAL.md.

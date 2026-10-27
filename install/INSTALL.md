# Install php56-hardened 1.0.0

Fix for PHP2Shell (CVE-2026-109618, CVE-2026-109619) on RHEL/CentOS 7 servers
running the Webtatic PHP 5.6.40 packages (php56w-*-5.6.40-1.w7) with Apache
mod_php. The PHP version stays 5.6.40; the package release changes to
1.w7.hardened.1.

Everything is in one file, `php56-hardened-1.0.0.run`. Its SHA-256 checksum is
sent separately from the file.

Restarting Apache causes a short outage, so install in an agreed change window,
on QT before production. Run every command as root (sudo -i).

## 1. Copy the file and check it

    cd /root
    sha256sum php56-hardened-1.0.0.run      # must match the checksum you were sent

If it doesn't match, stop: don't run the file.

## 2. Dry run (changes nothing)

    bash php56-hardened-1.0.0.run --dry-run

It must end with `DRY RUN OK`. It checks the server is RHEL/CentOS 7 on
php56w-5.6.40-1.w7, that Apache is running, that every installed php56w package
has a replacement, and runs a test transaction. If it says STOPPED, nothing was
changed: send the output to the build owner.

## 3. Install

If the server is a VM, take a snapshot first. Then:

    bash php56-hardened-1.0.0.run --url http://localhost/

Use a URL the server itself answers; `--url` is optional but recommended. The
installer shows its plan and asks you to type `yes`. Then it:

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

## Check at any time (changes nothing)

    bash php56-hardened-1.0.0.run --check

Every line must say PASS and the last line `RESULT: OK`.

## Rollback

    bash php56-hardened-1.0.0.run --rollback

This puts back unpatched php56w-5.6.40-1.w7 packages, removes
zz-php2shell.ini and restarts Apache. The Webtatic repository has been offline
since 2019, so the rollback packages are built from the same Webtatic recipe and
PHP source, without the patch. Restoring the VM snapshot is also a valid
rollback.

## Inspecting the contents

    bash php56-hardened-1.0.0.run --extract /tmp/inspect

Unpacks the packages, checksums and check script without installing anything.
The manual, step-by-step method is in INSTALL-MANUAL.md.

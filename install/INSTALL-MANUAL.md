# Install php56-hardened on a RHEL/CentOS 7 server

Hardened build of the Webtatic PHP 5.6.40 packages (php56w-*-5.6.40-1.w7) with a
fix for PHP2Shell (CVE-2026-109618, CVE-2026-109619). The PHP version stays
5.6.40; only the package release changes, to 1.w7.hardened.1.

Restarting Apache causes a short outage, so do this in an agreed change window,
on a test or QT server before production. Run every command as root (sudo -i).

## What's in the release folder

    php56-hardened/
      INSTALL.md     this file
      verify.sh      read-only check script
      SHA256SUMS     checksums of every package
      hardened/      the patched packages (php56w-*-5.6.40-1.w7.hardened.1)
      rollback/      unpatched packages (php56w-*-5.6.40-1.w7), for rollback

The Webtatic repository has been offline since 2019, so the rollback packages are
built from the same Webtatic recipe and PHP source, without the patch. They
replace the hardened packages with an unpatched build equivalent to what is
installed today.

## 1. Check this is the right server

    cat /etc/redhat-release     # must say release 7.x
    rpm -q php56w               # must be php56w-5.6.40-1.w7.x86_64
    httpd -M 2>/dev/null | grep php5_module    # must print php5_module

If any of these is different, stop and contact the build owner.

## 2. Unpack and check the release files

Copy the archive to /root on the server, then:

    cd /root
    sha256sum php56-hardened-*.tar.gz        # must match the checksum you were sent separately
    tar -xzf php56-hardened-*.tar.gz
    cd /root/php56-hardened
    sha256sum -c SHA256SUMS                  # every line must say OK

## 3. Back up

    mkdir -p /root/php-backup
    rpm -qa 'php*' | sort > /root/php-backup/packages-before.txt
    cp -a /etc/php.ini /etc/php.d /etc/httpd/conf.d/php.conf /root/php-backup/

If the server is a VM, take a snapshot as well.

## 4. Work out which packages to install

Only the php56w packages already on the server are replaced. Add-ons built
separately (php56w-pecl-*, php56w-pear) are not part of this release and stay as
they are. Run steps 4 and 5 in the same terminal.

    cd /root/php56-hardened/hardened
    FILES=""
    for p in $(rpm -qa --qf '%{NAME} %{SOURCERPM}\n' 'php56w*' | awk '$2 ~ /^php56w-5\.6\.40-/ {print $1}'); do
      f=$p-5.6.40-1.w7.hardened.1.x86_64.rpm
      if [ -f "$f" ]; then FILES="$FILES $f"; else echo "MISSING: $f"; fi
    done
    echo "Will install:$FILES"

If any MISSING line appears, stop.

## 5. Install, configure, restart

    yum -y --disablerepo='*' localinstall $FILES
    echo 'session.upload_progress.enabled = Off' > /etc/php.d/zz-php2shell.ini
    apachectl -t && systemctl restart httpd

The patch blocks session upload progress on its own; switching it off in config
is an extra layer. Drupal 6 and 7 don't use this PHP feature for their upload
progress bars.

Your existing /etc/php.ini and /etc/php.d files are kept. If yum reports a
.rpmnew file, leave it: it's the package default, and your file is still in use.

## 6. Verify

    cd /root/php56-hardened
    bash verify.sh

Every check must say PASS and the last line must say RESULT: OK. WARN lines
aren't failures, but report them. Then run the application smoke test (home
page, log in, browse, edit content, upload a file, run cron). Send the verify.sh
output and /root/php-backup/packages-before.txt back to the build owner.

## Rollback

    cd /root/php56-hardened/rollback
    FILES=""
    for p in $(rpm -qa --qf '%{NAME} %{SOURCERPM}\n' 'php56w*' | awk '$2 ~ /^php56w-5\.6\.40-/ {print $1}'); do
      f=$p-5.6.40-1.w7.x86_64.rpm
      if [ -f "$f" ]; then FILES="$FILES $f"; else echo "MISSING: $f"; fi
    done
    yum -y --disablerepo='*' downgrade $FILES
    rm -f /etc/php.d/zz-php2shell.ini
    apachectl -t && systemctl restart httpd
    rpm -q php56w               # must be php56w-5.6.40-1.w7.x86_64 (no "hardened")

If the server was snapshotted in step 3, restoring the snapshot is also a valid
rollback.

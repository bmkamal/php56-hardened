#!/bin/bash
# Checks the hardened PHP 5.6.40 build is installed and running. Read-only.
fail=0
pass() { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=1; }
warn() { echo "WARN  $1"; }

pkgs=$(rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SOURCERPM}\n' 'php56w*' \
       | awk '$2 ~ /^php56w-5\.6\.40-/ {print $1}')
old=$(echo "$pkgs" | grep -v hardened)
if [ -z "$pkgs" ]; then
  bad "no php56w-5.6.40 packages installed"
elif [ -z "$old" ]; then
  pass "all $(echo "$pkgs" | wc -l) php56w packages are the hardened build"
else
  bad "not hardened: $(echo $old)"
fi

for f in /usr/lib64/httpd/modules/libphp5.so /usr/lib64/httpd/modules/libphp5-zts.so /usr/sbin/php-fpm /usr/bin/php /usr/bin/php-cgi; do
  [ -e "$f" ] || continue
  rpm -qf "$f" | grep -q hardened && pass "$f is from the hardened build" || bad "$f is not from the hardened build"
done

grep -qa max_multipart_body_parts /usr/lib64/httpd/modules/libphp5.so 2>/dev/null \
  && pass "patched code present in the Apache PHP module" \
  || bad "Apache PHP module doesn't contain the patched code"

php -i 2>/dev/null | grep -q '^max_multipart_body_parts' \
  && pass "patched code present in command-line PHP (max_multipart_body_parts)" \
  || bad "max_multipart_body_parts setting missing: patched code not loaded"

errs=$(php -v 2>&1 | grep -iE 'warning|error|unable to load')
# During an install, ignore warnings PHP was already printing before the install
if [ -n "$errs" ] && [ -n "${PHP56H_BASELINE:-}" ] && [ -s "$PHP56H_BASELINE" ]; then
  errs=$(echo "$errs" | grep -vxFf "$PHP56H_BASELINE")
  [ -z "$errs" ] && warn "PHP prints start-up warnings, but they were already there before the install"
fi
[ -z "$errs" ] && pass "PHP starts cleanly with all extensions" || bad "PHP start-up errors: $errs"

pid=$(cat /run/httpd/httpd.pid 2>/dev/null || pidof -s httpd)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  pass "Apache (httpd) is running"
else
  bad "Apache (httpd) is not running"
fi

stale=$(grep -lE '(libphp5\.so|/php/modules/|/bin/php).*\(deleted\)' /proc/[0-9]*/maps 2>/dev/null \
        | cut -d/ -f3 | sort -un | tr '\n' ' ')
[ -z "$stale" ] && pass "no process is still running the old PHP files" \
  || bad "restart needed: process(es) $stale still use the replaced PHP files (systemctl restart httpd)"

up=$(php -r 'echo ini_get("session.upload_progress.enabled") ? "On" : "Off";' 2>/dev/null)
[ "$up" = "Off" ] && pass "session.upload_progress.enabled is Off" \
  || warn "session.upload_progress.enabled is On (the patch still blocks it; set Off as an extra layer)"

mem=$(php -r 'echo ini_get("memory_limit");' 2>/dev/null)
[ "$mem" = "-1" ] && warn "memory_limit is -1 (unlimited) in the PHP config; agree a real limit (e.g. 256M) with the application owner"

php -m 2>/dev/null | grep -qi '^xdebug' && warn "Xdebug is loaded; it's a debugging tool and shouldn't run on production"

[ "$fail" -eq 0 ] && echo "RESULT: OK" || echo "RESULT: PROBLEMS FOUND"
exit "$fail"

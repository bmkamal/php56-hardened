#!/bin/bash
# php-inventory.sh: lists every PHP on this server, its version, what it's used for
# and whether it's running. Read-only: it changes nothing and never runs any PHP file
# it finds (versions are read from the files, not by executing them).
# Run as root:  bash php-inventory.sh | tee /root/php-inventory-$(hostname -s).txt
# The output lists software versions and paths: treat it as internal, keep it out of
# public places (including the public GitHub repo), and delete it once reviewed.

export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo bash $0)"; exit 1; }

# Version stored inside a PHP program or module, read without running it
phpver() { grep -aoE -m1 'X-Powered-By: PHP/[0-9]+\.[0-9]+\.[0-9]+' "$1" 2>/dev/null | head -1 | sed 's/.*PHP\///'; }
owner()  { local o; o=$(rpm -qf "$1" 2>/dev/null) && echo "$o" | head -1; }
isbin()  { head -c 4 "$1" 2>/dev/null | grep -q 'ELF'; }
role()   {
  case "${1##*/}" in
    libphp*zts*) echo "Apache module (threaded)" ;;
    libphp*)     echo "Apache module" ;;
    php-fpm*)    echo "PHP-FPM service" ;;
    php-cgi*)    echo "CGI" ;;
    *)           echo "command line" ;;
  esac
}

# ---- 1. Which PHP files are running, and in how many processes ----------------------
# Apache/mod_php: processes with a libphp module mapped; FPM/CGI/CLI: the process's own program.
declare -A RUNNING STALE
for maps in /proc/[0-9]*/maps; do
  pid=${maps#/proc/}; pid=${pid%/maps}
  lib=$(grep -m1 -oE '/[^ ]*libphp[^ ]*\.so( \(deleted\))?' "$maps" 2>/dev/null)
  if [ -n "$lib" ]; then
    case "$lib" in *"(deleted)") STALE["${lib% (deleted)}"]=1; lib=${lib% (deleted)} ;; esac
    RUNNING["$lib"]=$(( ${RUNNING["$lib"]:-0} + 1 ))
  fi
  exe=$(readlink "/proc/$pid/exe" 2>/dev/null)
  case "${exe##*/}" in
    php|php[0-9]*|php-cgi*|php-fpm*|php*" (deleted)")
      case "$exe" in *"(deleted)") STALE["${exe% (deleted)}"]=1; exe=${exe% (deleted)} ;; esac
      RUNNING["$exe"]=$(( ${RUNNING["$exe"]:-0} + 1 )) ;;
  esac
done

# ---- 2. Every PHP program and module on local disks -------------------------------
FILES=$(nice -n 19 ionice -c3 find / \( -path /proc -o -path /sys -o -path /dev -o -path /run \
    -o -path /usr/lib/debug \
    -o -fstype nfs -o -fstype nfs4 -o -fstype cifs -o -fstype smbfs -o -fstype fuse.sshfs \) -prune -o -type f \
  \( -name php -o -name 'php[0-9]*' -o -name 'php-cgi*' -o -name 'php-fpm*' -o -name 'libphp*.so' \) \
  -print 2>/dev/null | sort)
# Add anything running from a file the search didn't find (e.g. already deleted)
for f in "${!RUNNING[@]}"; do echo "$FILES" | grep -qxF "$f" || FILES=$(printf '%s\n%s' "$FILES" "$f"); done

# ---- Summary -----------------------------------------------------------------------
echo "PHP inventory: $(hostname), $(date '+%Y-%m-%d %H:%M:%S %Z')"
cat /etc/redhat-release 2>/dev/null
echo
echo "================================ SUMMARY ================================"
printf '%-9s %-26s %-44s %-32s %s\n' "VERSION" "USED AS" "FILE" "PACKAGE" "RUNNING"
versions=""; unpackaged=""
while read -r f; do
  [ -n "$f" ] || continue
  [ -e "$f" ] && ! isbin "$f" && continue          # skip text files with php-like names
  v=$(phpver "$f"); v=${v:-?}
  p=$(owner "$f"); [ -n "$p" ] || { p="NOT FROM A PACKAGE"; unpackaged="$unpackaged $f"; }
  n=${RUNNING["$f"]:-0}
  if [ "$n" -gt 0 ]; then r="yes, $n process(es)"; versions="$versions $v"; else r="no"; fi
  [ -n "${STALE["$f"]:-}" ] && r="$r  <-- OLD COPY STILL RUNNING, restart needed"
  printf '%-9s %-26s %-44s %-32s %s\n' "$v" "$(role "$f")" "$f" "$p" "$r"
done <<< "$FILES"
echo
echo "PHP versions running: $(echo $versions | tr ' ' '\n' | sort -u | tr '\n' ' ')"
fpm=$(grep -rIlE 'proxy:fcgi|proxy:unix|SetHandler +"?proxy' /etc/httpd/conf /etc/httpd/conf.d /etc/httpd/conf.modules.d 2>/dev/null)
echo "Sites sending PHP to FPM/FastCGI: ${fpm:-none}"
web=$(ps -eo comm= | grep -xE 'nginx|lighttpd' | sort -u | tr '\n' ' ')
echo "Other web servers running: ${web:-none}"
ct=$(command -v docker podman containerd crictl kubelet 2>/dev/null | tr '\n' ' ')
echo "Container tools: ${ct:-none}"
echo "PHP files not from a package: ${unpackaged:-none}"

# ---- Details -----------------------------------------------------------------------
echo
echo "================================ DETAILS ================================"
echo
echo "-- PHP packages installed (any source)"
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | grep -i php | sort
echo
echo "-- PHP add-ons (extensions) configured to load"
grep -hE '^\s*(zend_)?extension\s*=' /etc/php.ini /etc/php.d/*.ini 2>/dev/null \
  | sed -E 's/^\s*(zend_)?extension\s*=\s*//; s/"//g' | sort -u | tr '\n' ' '; echo
echo
echo "-- Apache config that loads PHP (active files only)"
grep -HE '^\s*LoadModule\s+php' /etc/httpd/conf/*.conf /etc/httpd/conf.modules.d/*.conf /etc/httpd/conf.d/*.conf 2>/dev/null
echo
echo "-- What the site reports"
curl -sI -m 10 http://localhost/ | grep -iE '^(server|x-powered-by):' || echo "(no response or no version headers)"

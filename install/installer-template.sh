#!/bin/bash
# php56-hardened @@VERSION@@: single-file installer for the PHP2Shell fix
# (CVE-2026-109618, CVE-2026-109619) on RHEL/CentOS 7 servers running the
# Webtatic PHP 5.6.40 packages (php56w-*-5.6.40-1.w7) with Apache mod_php.
#
# Run as root:
#   bash php56-hardened-@@VERSION@@.run                 install (shows the plan and asks first)
#   bash php56-hardened-@@VERSION@@.run --yes           install without asking
#   bash php56-hardened-@@VERSION@@.run --dry-run       all pre-checks and a test transaction; changes nothing
#   bash php56-hardened-@@VERSION@@.run --check         report what's installed; changes nothing
#   bash php56-hardened-@@VERSION@@.run --rollback      put the unpatched packages back
#   bash php56-hardened-@@VERSION@@.run --extract DIR   unpack the contents for inspection; changes nothing
# Option for install:
#   --url URL   page to request after the restart (e.g. http://localhost/); no answer
#               or a 5xx answer counts as a failure and triggers automatic rollback
#
# Exit codes: 0 done; 1 stopped before changing anything; 2 install failed and was
# rolled back automatically; 3 rollback failed, manual action needed (see the log).

set -uo pipefail
umask 022
export LC_ALL=C

VERSION="@@VERSION@@"
PAYLOAD_SHA256="@@PAYLOAD_SHA256@@"
PHPVER=5.6.40
REL_STOCK=1.w7
REL_HARD=1.w7.hardened.1
LOG=/var/log/php56-hardened.log
STATE_DIR=/var/lib/php56-hardened
CONF=/etc/php.d/zz-php2shell.ini
CONF_LINE='session.upload_progress.enabled = Off'
SELF="$0"

MODE=install; ASSUME_YES=0; URL=""; EXTRACT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)   ASSUME_YES=1 ;;
    --dry-run)  MODE=dryrun ;;
    --check)    MODE=check ;;
    --rollback) MODE=rollback ;;
    --extract)  MODE=extract; EXTRACT_DIR="${2:-}"; shift ;;
    --url)      URL="${2:-}"; shift ;;
    -h|--help)  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$SELF"; exit 0 ;;
    *) echo "Unknown option: $1 (use --help)" >&2; exit 1 ;;
  esac
  shift
done

say()  { echo "[php56-hardened] $*"; }
die()  { echo "[php56-hardened] STOPPED, nothing was changed: $*" >&2; exit 1; }

# ---------- payload ----------
unpack() {  # $1 = target directory
  local line sum
  line=$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit }' "$SELF")
  [ -n "$line" ] || die "this installer file is damaged (no payload found)"
  sum=$(tail -n +"$line" "$SELF" | sha256sum | cut -d' ' -f1)
  [ "$sum" = "$PAYLOAD_SHA256" ] || die "this installer file is damaged or has been changed (payload checksum mismatch)"
  mkdir -p "$1" || die "can't create $1"
  tail -n +"$line" "$SELF" | tar -xzf - -C "$1" || die "can't unpack the payload"
  ( cd "$1/php56-hardened" && sha256sum -c --quiet SHA256SUMS ) || die "package checksum mismatch inside the payload"
}

if [ "$MODE" = extract ]; then
  [ -n "$EXTRACT_DIR" ] || { echo "Usage: --extract DIR" >&2; exit 1; }
  unpack "$EXTRACT_DIR"
  say "unpacked to $EXTRACT_DIR/php56-hardened (all checksums OK)"
  exit 0
fi

# ---------- everything else needs root, a lock and a log ----------
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo bash $SELF ...)" >&2; exit 1; }
exec 9>/var/run/php56-hardened.lock
flock -n 9 || die "another php56-hardened run is in progress"
touch "$LOG" && chmod 600 "$LOG"
exec > >(tee -a "$LOG") 2>&1
say "version $VERSION, mode $MODE, $(date '+%Y-%m-%d %H:%M:%S %Z'), host $(hostname)"

WORK=$(mktemp -d /var/tmp/php56-hardened.XXXXXX) || die "can't create a work folder in /var/tmp"
trap 'rm -rf "$WORK"' EXIT
unpack "$WORK"
PAY="$WORK/php56-hardened"
say "installer integrity OK (payload and all package checksums match)"

# ---------- helpers ----------
# Installed packages built from the php56w-5.6.40 source: "name release"
installed() {
  rpm -qa --qf '%{NAME} %{VERSION} %{RELEASE} %{SOURCERPM}\n' 'php56w*' \
    | awk -v v="$PHPVER" '$2 == v && $4 ~ /^php56w-5\.6\.40-/ { print $1, $3 }' | sort
}

# Files in $1 for the installed packages whose release is $2, built for release $3
# Sets FILES and MISSING.
pick() {
  local name rel f
  FILES=""; MISSING=""
  while read -r name rel; do
    [ -n "$name" ] && [ "$rel" = "$2" ] || continue
    f="$1/$name-$PHPVER-$3.x86_64.rpm"
    if [ -f "$f" ]; then FILES="$FILES $f"; else MISSING="$MISSING $name"; fi
  done <<< "$(installed)"
}

httpd_pid() {
  local p
  p=$(cat /run/httpd/httpd.pid 2>/dev/null)
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null && echo "$p"
}

restart_apache() {
  httpd -t >/dev/null 2>&1 || { httpd -t; say "Apache config test failed"; return 1; }
  if [ -d /run/systemd/system ]; then
    systemctl restart httpd 9>&- || return 1
    if systemctl is-active --quiet php-fpm 2>/dev/null; then systemctl restart php-fpm 9>&- || return 1; fi
  else  # no systemd (e.g. a test container)
    httpd -k stop 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -z "$(httpd_pid)" ] && break; sleep 1; done
    httpd -k start </dev/null 9>&- || return 1   # 9>&-: Apache mustn't inherit our lock
  fi
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -n "$(httpd_pid)" ] && return 0; sleep 1; done
  say "Apache didn't come back up"; return 1
}

smoke() {
  local code
  [ -n "$URL" ] || return 0
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "$URL")
  say "smoke test $URL answered HTTP $code"
  [ "$code" != "000" ] && [ "$code" -lt 500 ]
}

# Put the unpatched packages back for anything currently hardened
downgrade() {
  pick "$PAY/rollback" "$REL_HARD" "$REL_STOCK"
  [ -z "$MISSING" ] || { say "no rollback package for:$MISSING"; return 1; }
  [ -n "$FILES" ] || { say "no hardened packages installed"; return 0; }
  say "rolling back:$(for f in $FILES; do printf ' %s' "${f##*/}"; done)"
  yum -y -q --disablerepo='*' downgrade $FILES
}

remove_conf() {
  if [ -f "$CONF" ] && [ "$(cat "$CONF")" = "$CONF_LINE" ]; then rm -f "$CONF"; fi
}

auto_rollback() {
  say "INSTALL FAILED: $1"
  say "rolling back automatically"
  if downgrade && remove_conf && restart_apache \
     && [ -z "$(installed | awk -v r="$REL_HARD" '$2 == r')" ]; then
    say "ROLLED BACK: the server is back on php56w-$PHPVER-$REL_STOCK and Apache is running"
    say "log: $LOG"
    exit 2
  fi
  say "ROLLBACK FAILED: manual action needed. Packages now:"
  installed | sed 's/^/    /'
  say "log: $LOG, backup: ${BACKUP:-none}"
  exit 3
}

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local ans=""
  ( exec </dev/tty ) 2>/dev/null || die "no terminal to ask for confirmation; re-run with --yes"
  read -r -p "[php56-hardened] $1 Type yes to continue: " ans </dev/tty
  [ "$ans" = "yes" ] || die "not confirmed"
}

# ---------- modes ----------
if [ "$MODE" = check ]; then
  bash "$PAY/verify.sh"; exit $?
fi

grep -q 'release 7\.' /etc/redhat-release 2>/dev/null || die "this isn't RHEL/CentOS 7 ($(cat /etc/redhat-release 2>/dev/null))"
[ "$(uname -m)" = x86_64 ] || die "this isn't an x86_64 server"
CURRENT=$(installed)
[ -n "$CURRENT" ] || die "no php56w $PHPVER packages are installed"
OTHER=$(echo "$CURRENT" | awk -v a="$REL_STOCK" -v b="$REL_HARD" '$2 != a && $2 != b')
[ -z "$OTHER" ] || die "unexpected package release(s): $(echo $OTHER)"

if [ "$MODE" = rollback ]; then
  pick "$PAY/rollback" "$REL_HARD" "$REL_STOCK"
  if [ -z "$FILES" ] && [ -z "$MISSING" ]; then
    say "nothing to roll back: no hardened packages are installed"; exit 0
  fi
  [ -z "$MISSING" ] || die "no rollback package for:$MISSING"
  rpm -U --oldpackage --test $FILES || die "test transaction for the rollback failed"
  confirm "Roll back $(echo $FILES | wc -w) packages to $PHPVER-$REL_STOCK and restart Apache."
  BACKUP=/root/php56-hardened-backup-$(date +%Y%m%d-%H%M%S)
  mkdir -p "$BACKUP" && rpm -qa 'php*' | sort > "$BACKUP/packages-before.txt"
  if downgrade && remove_conf && restart_apache; then
    say "ROLLED BACK: $(rpm -q php56w); Apache is running"
    rm -f "$STATE_DIR/installed"
    exit 0
  fi
  say "ROLLBACK FAILED: manual action needed (log: $LOG)"; exit 3
fi

# install / dry-run
[ -n "$(httpd_pid)" ] || die "Apache (httpd) isn't running; start it first so the result can be checked"
pick "$PAY/hardened" "$REL_STOCK" "$REL_HARD"
if [ -z "$FILES" ] && [ -z "$MISSING" ]; then
  say "already installed: every php56w package is $PHPVER-$REL_HARD. Running the check:"
  bash "$PAY/verify.sh"; exit $?
fi
[ -z "$MISSING" ] || die "this release has no hardened package for:$MISSING"
FREE=$(df -Pm /usr | awk 'NR == 2 { print $4 }')
[ "${FREE:-0}" -ge 200 ] || die "less than 200 MB free on /usr"
rpm -U --test $FILES || die "test transaction failed (dependency or conflict problem above)"

say "plan: replace $(echo $FILES | wc -w) packages with $PHPVER-$REL_HARD:"
for f in $FILES; do echo "    ${f##*/}"; done
say "then: add $CONF, restart Apache, run the check${URL:+, request $URL}"
if [ "$MODE" = dryrun ]; then say "DRY RUN OK: all pre-checks and the test transaction passed. Nothing was changed."; exit 0; fi
confirm "This restarts Apache (short outage)."

BACKUP=/root/php56-hardened-backup-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP" || die "can't create $BACKUP"
rpm -qa 'php*' | sort > "$BACKUP/packages-before.txt"
for p in /etc/php.ini /etc/php.d /etc/httpd/conf.d/php.conf; do [ -e "$p" ] && cp -a "$p" "$BACKUP/"; done
say "backup: $BACKUP"

if ! yum -y -q --disablerepo='*' localinstall $FILES; then
  if [ -z "$(installed | awk -v r="$REL_HARD" '$2 == r')" ]; then
    die "yum couldn't install the packages (see above)"
  fi
  auto_rollback "yum stopped part-way"
fi
[ -e "$CONF" ] || echo "$CONF_LINE" > "$CONF"

restart_apache || auto_rollback "Apache didn't restart cleanly"
bash "$PAY/verify.sh" || auto_rollback "the check found problems (see the FAIL lines above)"
smoke || auto_rollback "the smoke test page didn't answer properly"

mkdir -p "$STATE_DIR"
printf 'version=%s\ndate=%s\nbackup=%s\n' "$VERSION" "$(date '+%F %T')" "$BACKUP" > "$STATE_DIR/installed"
say "DONE: php56-hardened $VERSION installed and checked. Backup: $BACKUP. Log: $LOG"
exit 0
__PAYLOAD_BELOW__

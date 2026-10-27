#!/bin/bash
# Side-by-side demo of the five tests: stock PHP 5.4 (port 8081) vs patched (port 8082).
# Uses the php-stock and php-patched containers from Step 6. Run from the repo folder.
S=http://localhost:8081/test
P=http://localhost:8082/test

pause() { echo; read -r -p "Press Enter for the next test..." _; clear; }
hdr() {
  echo "=========================================================="
  echo " $1"
  echo "=========================================================="
  echo
}

docker start php-stock php-patched >/dev/null && sleep 2
clear

hdr "Test 1: Both containers run PHP 5.4.16"
echo "STOCK:   PHP $(curl -s $S/ver.php)   package: $(docker exec php-stock rpm -q php)"
echo "PATCHED: PHP $(curl -s $P/ver.php)   package: $(docker exec php-patched rpm -q php)"
pause

hdr "Test 2: Is the patched code loaded?"
echo "STOCK:"
docker exec php-stock php -i 2>/dev/null | grep max_multipart_body_parts || echo "  (setting does not exist - old code)"
echo
echo "PATCHED:"
docker exec php-patched php -i 2>/dev/null | grep max_multipart_body_parts
pause

hdr "Test 3: Session upload progress (main PHP 5.4 attack route)"
echo "Uploading a 2 MB file with the PHP_SESSION_UPLOAD_PROGRESS field, then reading the session."
echo "Upload progress is switched ON in both containers' settings."
echo
head -c 2000000 /dev/urandom > /tmp/demo.bin
for PORT in 8081 8082; do
  if [ "$PORT" = 8081 ]; then echo "STOCK session:"; else echo "PATCHED session:"; fi
  J=/tmp/demo-jar-$PORT
  rm -f "$J"
  curl -s -c "$J" -b "$J" http://localhost:$PORT/test/progress.php > /dev/null
  curl -s -c "$J" -b "$J" -F "PHP_SESSION_UPLOAD_PROGRESS=demo" -F "file=@/tmp/demo.bin" http://localhost:$PORT/test/progress.php > /dev/null
  curl -s -c "$J" -b "$J" http://localhost:$PORT/test/progress.php | head -12
  echo
done
rm -f /tmp/demo.bin /tmp/demo-jar-*
pause

hdr "Test 4: Upload part limit (60 form fields sent, limit 50)"
args=()
for i in $(seq 1 60); do args+=(-F "f$i=x"); done
echo "STOCK accepted:   $(curl -s "${args[@]}" $S/count.php)"
echo "PATCHED accepted: $(curl -s "${args[@]}" $P/count.php)"
echo
echo "PATCHED log:"
docker exec php-patched tail -1 /var/log/httpd/error_log | sed 's/^.*PHP Warning/  PHP Warning/'
pause

hdr "Test 5: Running out of memory"
echo "The page uses 32 MB with a 16 MB limit, and logs 'SHUTDOWN RAN' if PHP keeps running code afterwards."
echo
echo "STOCK HTTP status: $(curl -s -o /dev/null -w '%{http_code}' $S/oom.php)"
sleep 1
echo "STOCK log:"
docker exec php-stock tail -2 /var/log/httpd/error_log | sed 's/^.*\] /  /'
echo
echo "PATCHED HTTP status: $(curl -s -o /dev/null -w '%{http_code}' $P/oom.php)"
sleep 1
echo "PATCHED log:"
docker exec php-patched tail -2 /var/log/httpd/error_log | sed 's/^/  /'
echo
echo "Stock: 'SHUTDOWN RAN' means PHP kept running code after the memory error."
echo "Patched: the worker stopped immediately and nothing else ran."
echo
echo "Demo complete."

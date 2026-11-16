#!/bin/sh
# Server di posta finto per gli screenshot dello Store: GreenMail su localhost (IMAPS 3993, SMTPS 3465), due caselle
# demo@example.com e demo@example.org (password demo-pass), TLS con una CA usa-e-getta, posta da seed.py.
# Uso: tool/store_screenshots/server.sh <it|en> <cartella di lavoro>   (Ctrl-C per fermarlo; la posta è in memoria)
set -eu
lang=$1 dir=$2
here=$(cd "$(dirname "$0")" && pwd)
# ponytail: versione e SHA-256 copiati da test/support/greenmail_server.dart; aggiornarli insieme.
ver=2.1.15 sha=91d58798698cac357f015365240383b936ced2f2a1a9f7db37d9e3e1a31391b1
O=$(brew --prefix openssl@3)/bin/openssl
if nc -z 127.0.0.1 3993 2>/dev/null; then echo "la porta 3993 è già occupata (un altro server?)" >&2; exit 1; fi
mkdir -p "$dir" && cd "$dir"
jar=greenmail-standalone-$ver.jar
if [ ! -f $jar ]; then
  curl -sf -o $jar.part https://repo1.maven.org/maven2/com/icegreen/greenmail-standalone/$ver/$jar
  mv $jar.part $jar
fi
echo "$sha  $jar" | shasum -a 256 -c - >/dev/null || { rm -f $jar; echo "checksum del jar sbagliato" >&2; exit 1; }
# CA e certificato validi 30 giorni, rifatti quando mancano o scadono entro un giorno (la nuova CA va rifidata).
if [ ! -f srv.p12 ] || ! $O x509 -checkend 86400 -noout -in srv.pem >/dev/null 2>&1; then
  $O req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem -days 30 -subj "/CN=Postino Demo CA" \
    -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
  $O req -newkey rsa:2048 -nodes -keyout srv.key -out srv.csr -subj "/CN=localhost" 2>/dev/null
  printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\nbasicConstraints=CA:FALSE\n' > ext.cnf
  $O x509 -req -in srv.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out srv.pem -days 30 -extfile ext.cnf 2>/dev/null
  $O pkcs12 -export -in srv.pem -inkey srv.key -certfile ca.pem -out srv.p12 -passout pass:demodemo -name demo
fi
java -Dgreenmail.setup.test.all -Dgreenmail.users=demo:demo-pass@example.com,demo:demo-pass@example.org \
  -Dgreenmail.users.login=email -Dgreenmail.tls.keystore.file=srv.p12 -Dgreenmail.tls.keystore.password=demodemo \
  -jar $jar > greenmail.log 2>&1 &
pid=$!
trap 'kill $pid' EXIT INT TERM
i=0
until nc -z 127.0.0.1 3993 2>/dev/null; do
  i=$((i + 1))
  if [ $i -gt 60 ] || ! kill -0 $pid 2>/dev/null; then tail greenmail.log >&2; exit 1; fi
  sleep 1
done
python3 -I "$here/seed.py" "$lang" ca.pem
echo "Pronto. CA da fidare nel simulatore: xcrun simctl keychain <udid> add-root-cert $dir/ca.pem"
wait

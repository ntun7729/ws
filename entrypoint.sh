#!/bin/sh
set -eu

: "${VLESS_UUID:?VLESS_UUID is required}"
: "${WS_PATH:=/r9q2x7b6p4w8}"
: "${PORT:=80}"
: "${XRAY_PORT:=10001}"

case "$WS_PATH" in
  /*) ;;
  *) WS_PATH="/$WS_PATH" ;;
esac

case "$PORT" in
  ''|*[!0-9]*) echo "PORT must be a number" >&2; exit 1 ;;
esac

case "$XRAY_PORT" in
  ''|*[!0-9]*) echo "XRAY_PORT must be a number" >&2; exit 1 ;;
esac

if [ "$PORT" = "$XRAY_PORT" ]; then
  echo "PORT and XRAY_PORT must be different" >&2
  exit 1
fi

export VLESS_UUID WS_PATH PORT XRAY_PORT

envsubst '${PORT} ${XRAY_PORT} ${WS_PATH}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf
envsubst '${VLESS_UUID} ${XRAY_PORT} ${WS_PATH}' < /etc/xray/xray.json.template > /etc/xray/config.json

/usr/local/bin/xray run -test -c /etc/xray/config.json >/dev/null 2>&1
nginx -t >/dev/null 2>&1

su-exec xray:xray /usr/local/bin/xray run -c /etc/xray/config.json >/dev/null 2>&1 &
XRAY_PID="$!"

nginx -g 'daemon off;' >/dev/null 2>&1 &
NGINX_PID="$!"

term_handler() {
  kill "$XRAY_PID" "$NGINX_PID" 2>/dev/null || true
  wait "$XRAY_PID" "$NGINX_PID" 2>/dev/null || true
  exit 0
}

trap term_handler INT TERM

while true; do
  if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    kill "$NGINX_PID" 2>/dev/null || true
    exit 1
  fi
  if ! kill -0 "$NGINX_PID" 2>/dev/null; then
    kill "$XRAY_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 5
done

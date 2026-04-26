#!/bin/sh
set -eu

: "${VLESS_UUID:?VLESS_UUID is required}"
: "${WS_PATH:=/r9q2x7b6p4w8}"

case "$WS_PATH" in
  /*) ;;
  *) WS_PATH="/$WS_PATH" ;;
esac

export VLESS_UUID WS_PATH

echo "Rendering service configuration"
envsubst '${WS_PATH}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf
envsubst '${VLESS_UUID} ${WS_PATH}' < /etc/xray/xray.json.template > /etc/xray/config.json

echo "Validating internal proxy configuration"
/usr/local/bin/xray run -test -c /etc/xray/config.json >/dev/null 2>&1

echo "Validating Nginx configuration"
nginx -t

echo "Starting internal proxy"
su-exec xray:xray /usr/local/bin/xray run -c /etc/xray/config.json >/dev/null 2>&1 &
XRAY_PID="$!"

echo "Starting Nginx"
nginx -g 'daemon off;' &
NGINX_PID="$!"

term_handler() {
  echo "Stopping services"
  kill "$XRAY_PID" "$NGINX_PID" 2>/dev/null || true
  wait "$XRAY_PID" "$NGINX_PID" 2>/dev/null || true
  exit 0
}

trap term_handler INT TERM

while true; do
  if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "Internal proxy process exited" >&2
    kill "$NGINX_PID" 2>/dev/null || true
    exit 1
  fi
  if ! kill -0 "$NGINX_PID" 2>/dev/null; then
    echo "Nginx process exited" >&2
    kill "$XRAY_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 5
done

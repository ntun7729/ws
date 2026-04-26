# xray-nginx-vless-ws

Container image for **Nginx + Xray VLESS over WebSocket** with no TLS inside the container.

- `/` serves a normal static web page from Nginx.
- `/r9q2x7b6p4w8` proxies WebSocket traffic to Xray.
- Xray and Nginx logs are disabled.
- TLS should be terminated before this container, for example by Cloudflare, a load balancer, or another reverse proxy.

## Defaults

| Setting | Value |
|---|---|
| Container listen port | `80/tcp` |
| Xray listen address | `127.0.0.1:10000` |
| WebSocket path | `/r9q2x7b6p4w8` |
| TLS in Nginx/Xray | disabled |
| Logs | disabled |

## Run with Docker

Generate a UUID first:

```bash
cat /proc/sys/kernel/random/uuid
```

Run:

```bash
docker run -d \
  --name xray-nginx-ws \
  --restart unless-stopped \
  -p 80:80 \
  -e VLESS_UUID="YOUR_UUID_HERE" \
  ghcr.io/ntun7729/ws:latest
```

Optional custom WebSocket path:

```bash
docker run -d \
  --name xray-nginx-ws \
  --restart unless-stopped \
  -p 80:80 \
  -e VLESS_UUID="YOUR_UUID_HERE" \
  -e WS_PATH="/mysecretpath" \
  ghcr.io/ntun7729/ws:latest
```

## Run with Docker Compose

```bash
cp env.example .env
nano .env
docker compose up -d
```

## Client examples

If TLS is terminated before the container and the client connects to a TLS front such as Cloudflare:

```text
vless://YOUR_UUID_HERE@your.domain.com:443?encryption=none&security=tls&type=ws&host=your.domain.com&path=%2Fr9q2x7b6p4w8#xray-nginx-ws
```

If connecting directly to this container without TLS:

```text
vless://YOUR_UUID_HERE@your.server.ip:80?encryption=none&security=none&type=ws&host=your.server.ip&path=%2Fr9q2x7b6p4w8#xray-nginx-ws-direct
```

## Cloudflare Tunnel example

In Cloudflare Tunnel public hostname settings, point the service to plain HTTP:

```text
Hostname: your.domain.com
Service:  http://localhost:80
```

Then use the TLS client URI above with `your.domain.com:443`.

## Notes

WebSocket support in Nginx requires explicitly passing `Upgrade` and `Connection` headers to the backend. This image does that in `config/nginx.conf.template`.

Xray access/error logs are set to `none`, and Nginx access/error logs are disabled. The entrypoint also redirects daemon output to `/dev/null`.

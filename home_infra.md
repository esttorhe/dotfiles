# Runbook: Adding New Service to Nginx Proxy Manager with Pi-hole DNS

## Prerequisites
- Running Pi-hole instance (192.168.178.43)
- Running NPM instance (192.168.178.69)
- New service running on 192.168.178.69 with known port

## Steps

### 1. Add DNS Entry in Pi-hole
1. Access Pi-hole admin interface
2. Go to "Local DNS" → "DNS Records"
3. Add new record:
   - Domain: `servicename.home`
   - IP Address: 192.168.178.69
4. Note: If UI prevents adding multiple domains to same IP, use existing working domain as reference

### 2. Add Nginx Configuration
1. SSH into your Pi-hole host
2. Connect to NPM container:
```bash
docker exec -it nginx-proxy-manager /bin/sh
```

3. Create new proxy configuration (replace XX with next available number, servicename with your service name, and PORT with your service port):
```bash
printf '# ------------------------------------------------------------\n# servicename.home\n# ------------------------------------------------------------\n\nmap $scheme $hsts_header {\n    https   "max-age=63072000; preload";\n}\n\nserver {\n  set $forward_scheme http;\n  set $server         "192.168.178.69";\n  set $port           PORT;\n\n  listen 80;\n  listen [::]:80;\n\n  server_name servicename.home;\n  http2 off;\n\n  # Block Exploits\n  include conf.d/include/block-exploits.conf;\n\n  access_log /data/logs/proxy-host-XX_access.log proxy;\n  error_log /data/logs/proxy-host-XX_error.log warn;\n\n  proxy_hide_header X-Frame-Options;\n  ssl_verify_client off;\n  proxy_ssl_verify off;\n\n  location / {\n    proxy_pass http://192.168.178.69:PORT;\n    proxy_set_header Host $host;\n    proxy_set_header Upgrade $http_upgrade;\n    proxy_set_header Connection "upgrade";\n  }\n}\n' > /data/nginx/proxy_host/XX.conf
```

4. Reload nginx:
```bash
nginx -s reload
```

### 3. Verify Configuration
1. Check nginx error log:
```bash
tail -f /data/logs/proxy-host-XX_error.log
```

2. Test DNS resolution:
```bash
nslookup servicename.home
```
Expected result should show 192.168.178.69

3. Test service access in browser:
```
http://servicename.home
```

## Troubleshooting
- If service shows "offline" in NPM UI but works: This is normal, continue if service works
- If getting 400 error: Check port number in configuration
- If getting DNS error: Verify Pi-hole DNS entry
- If getting connection refused: Verify service is running and port is correct

## Example Configuration
For a service running on port 3000:
```bash
printf '# ------------------------------------------------------------\n# myapp.home\n# ------------------------------------------------------------\n\nmap $scheme $hsts_header {\n    https   "max-age=63072000; preload";\n}\n\nserver {\n  set $forward_scheme http;\n  set $server         "192.168.178.69";\n  set $port           3000;\n\n  listen 80;\n  listen [::]:80;\n\n  server_name myapp.home;\n  http2 off;\n\n  # Block Exploits\n  include conf.d/include/block-exploits.conf;\n\n  access_log /data/logs/proxy-host-4_access.log proxy;\n  error_log /data/logs/proxy-host-4_error.log warn;\n\n  proxy_hide_header X-Frame-Options;\n  ssl_verify_client off;\n  proxy_ssl_verify off;\n\n  location / {\n    proxy_pass http://192.168.178.69:3000;\n    proxy_set_header Host $host;\n    proxy_set_header Upgrade $http_upgrade;\n    proxy_set_header Connection "upgrade";\n  }\n}\n' > /data/nginx/proxy_host/4.conf
```

Remember to increment the proxy host number (4.conf, 5.conf, etc.) for each new service.



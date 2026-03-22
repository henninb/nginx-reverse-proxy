# Proxmox VE Reverse Proxy — Lessons Learned

## Problem: Confirmation Modal Not Appearing for Stop VM

### Root Cause (Multi-Layered)

**Layer 1 — X-Frame-Options**
The global `add_header X-Frame-Options DENY always` in the `http` block was the starting
suspect. The fix: put `proxy_hide_header X-Frame-Options` and `add_header X-Frame-Options
SAMEORIGIN always` in the `location /` block (not the server block) so the override is
unambiguous and applies precisely where `proxy_pass` runs.

**Layer 2 — Content-Security-Policy**
Proxmox VE's upstream CSP (`default-src 'self' 'unsafe-eval'`) was blocking things silently:
- Without CSP override: ExtJS shadow-rendering error (`insertBefore` on null) was caught
  silently → dialog failed to render with no console output
- With CSP completely removed: same error became uncaught → visible JS error in console
- Fix: replace the upstream CSP (via `proxy_hide_header Content-Security-Policy` + custom
  `add_header Content-Security-Policy`) with a permissive version that adds:
  - `'unsafe-inline'` to `default-src` (Proxmox uses inline scripts)
  - `img-src 'self' data: blob:` (ExtJS uses `data:` URIs for component icons/shadows)

**Layer 3 — Dialog Positioned Off-Screen**
Even after layers 1 & 2 were fixed, the dialog was in the DOM but at `left: 1893px; top:
1263px` — far off-screen. Confirmed by inspecting `.x-message-box` in DevTools Elements.

Root cause of off-screen positioning: ExtJS 7's `Ext.Msg.center()` uses
`Ext.getBody().getWidth()` which reads `document.body.offsetWidth`. Through the nginx proxy,
`body.offsetWidth` reports ~4036px (instead of the actual ~1920px viewport width), causing
the centering calculation to place the dialog at the document center rather than the viewport
center. Direct access (`192.168.10.5:8006`) did not exhibit this because the body was
properly constrained there.

Fix: inject CSS via `sub_filter` to force viewport-relative centering:
```
.x-message-box {
  position: fixed !important;
  left: 50% !important;
  top: 50% !important;
  transform: translate(-50%, -50%) !important;
  margin: 0 !important;
}
```
`position: fixed` makes the element position relative to the viewport, completely bypassing
the inflated `body.offsetWidth` calculation.

### Diagnostic Steps That Were Useful
1. **DevTools → Elements**: search for `.x-message-box` after clicking Stop — confirmed the
   dialog existed in DOM but was off-screen
2. **Browser console test**: `Ext.Msg.confirm('Test', 'Test', Ext.emptyFn)` — appeared
   correctly from console, confirming ExtJS itself worked; the issue was specific to the
   button handler's dialog positioning context
3. **Direct access test** (`192.168.10.5:8006`) — confirmed the issue was proxy-specific

### Final Working nginx Config for Proxmox Location Blocks

```nginx
location / {
  proxy_pass https://proxmox;
  proxy_ssl_name "proxmox.bhenning.com";   # or brianhenning.com
  proxy_ssl_server_name on;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_ssl_verify off;

  # Prevent double-compression
  proxy_set_header Accept-Encoding "";

  # WebSocket support for noVNC/SPICE console
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $connection_upgrade;

  # Long timeouts for console sessions
  proxy_connect_timeout 7d;
  proxy_send_timeout 7d;
  proxy_read_timeout 7d;

  # Streaming for noVNC console
  proxy_buffering off;

  # Override frame/CSP headers
  proxy_hide_header X-Frame-Options;
  proxy_hide_header Content-Security-Policy;
  add_header X-Frame-Options SAMEORIGIN always;
  add_header Content-Security-Policy "default-src 'self' 'unsafe-eval' 'unsafe-inline'; font-src 'self' data:; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:;" always;

  # Fix ExtJS dialog off-screen centering (body.offsetWidth ~4036px through proxy)
  sub_filter '</head>' '<style>.x-message-box{position:fixed!important;left:50%!important;top:50%!important;transform:translate(-50%,-50%)!important;margin:0!important;}</style></head>';
  sub_filter_once on;
}
```

### Key Facts About Proxmox VE + nginx
- `sub_filter` requires uncompressed upstream responses — guaranteed by `proxy_set_header
  Accept-Encoding ""`
- `proxy_buffering off` is needed for noVNC WebSocket console; does NOT interfere with
  `sub_filter` on HTML responses
- Proxmox's own `X-Frame-Options: SAMEORIGIN` must be hidden and re-added, otherwise
  double headers can cause browser to use the more restrictive one
- `http2 off` is mandatory for pveproxy compatibility
- The `$connection_upgrade` map (upgrade vs empty string) is the correct pattern for
  serving both WebSocket and regular HTTP from the same location block
- Proxmox cookies do not include an explicit `Domain` attribute, so they correctly bind
  to whatever hostname the browser is using (the proxy hostname)

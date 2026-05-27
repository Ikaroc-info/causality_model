#!/usr/bin/env python3
"""
relay_server.py - Mini serveur de relay de messages entre machines.
Usage:
    python relay_server.py [port]   (defaut: 5000)

Endpoints:
    POST /log       body = texte libre  -> stocke et affiche le message
    GET  /          -> page HTML avec tous les messages recus
    GET  /messages  -> JSON brut des messages
"""

import sys
import json
import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT    = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
messages = []   # liste de {time, source, text}


class Handler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        # Silence the default Apache-style access log
        pass

    # ------------------------------------------------------------------
    def do_POST(self):
        if self.path != "/log":
            self._reply(404, "text/plain", b"Not found")
            return

        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length).decode("utf-8", errors="replace")
        source = self.headers.get("X-Source", self.client_address[0])

        entry = {
            "time":   datetime.datetime.now().strftime("%H:%M:%S"),
            "source": source,
            "text":   body,
        }
        messages.append(entry)

        # Print to console
        sep = "-" * 60
        print(f"\n{sep}")
        print(f"[{entry['time']}] FROM {entry['source']}")
        print(entry["text"])
        print(sep)
        sys.stdout.flush()

        self._reply(200, "text/plain", b"OK")

    # ------------------------------------------------------------------
    def do_GET(self):
        if self.path == "/messages":
            data = json.dumps(messages, ensure_ascii=False, indent=2).encode()
            self._reply(200, "application/json", data)

        elif self.path == "/":
            self._reply(200, "text/html; charset=utf-8", self._build_html())

        else:
            self._reply(404, "text/plain", b"Not found")

    # ------------------------------------------------------------------
    def _reply(self, code, ctype, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _build_html(self) -> bytes:
        rows = ""
        for m in reversed(messages):
            text_escaped = (m["text"]
                            .replace("&", "&amp;")
                            .replace("<", "&lt;")
                            .replace(">", "&gt;"))
            rows += f"""
            <tr>
              <td style="white-space:nowrap;color:#888">{m['time']}</td>
              <td style="white-space:nowrap;color:#aaa;padding:0 12px">{m['source']}</td>
              <td><pre style="margin:0;white-space:pre-wrap">{text_escaped}</pre></td>
            </tr>"""

        if not rows:
            rows = '<tr><td colspan="3" style="color:#666;text-align:center;padding:32px">Aucun message recu.</td></tr>'

        html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="3">
  <title>Relay Server</title>
  <style>
    body  {{ background:#1a1a2e; color:#e0e0e0; font-family:monospace; padding:24px; margin:0 }}
    h1    {{ color:#00d4ff; margin-bottom:4px }}
    p     {{ color:#888; margin-bottom:20px; font-size:13px }}
    table {{ width:100%; border-collapse:collapse }}
    tr    {{ border-bottom:1px solid #2a2a4a }}
    tr:hover {{ background:#252545 }}
    td    {{ padding:8px 4px; vertical-align:top; font-size:13px }}
    pre   {{ font-family:monospace; color:#f0f0f0 }}
  </style>
</head>
<body>
  <h1>Relay Server</h1>
  <p>Port {PORT} &nbsp;|&nbsp; {len(messages)} message(s) &nbsp;|&nbsp; Rafraichissement auto toutes les 3s</p>
  <table>
    <thead>
      <tr style="color:#00d4ff">
        <th style="text-align:left;padding:4px">Heure</th>
        <th style="text-align:left;padding:4px">Source</th>
        <th style="text-align:left;padding:4px">Message</th>
      </tr>
    </thead>
    <tbody>{rows}</tbody>
  </table>
</body>
</html>"""
        return html.encode("utf-8")


if __name__ == "__main__":
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)

    print(f"Relay Server demarrage sur le port {PORT}")
    print(f"  Local  : http://localhost:{PORT}/")
    print(f"  Reseau : http://{local_ip}:{PORT}/")
    print(f"  POST   : http://<ip>:{PORT}/log")
    print("Ctrl+C pour arreter\n")

    server = HTTPServer(("0.0.0.0", PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServeur arrete.")

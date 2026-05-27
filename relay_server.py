#!/usr/bin/env python3
"""
relay_server.py - Mini serveur HTTP de relay de messages entre machines.

Usage:
    python relay_server.py [--port 8765] [--host 0.0.0.0]

Endpoints:
    POST /log   body=texte brut   -> stocke et affiche le message
    GET  /log                     -> retourne tous les messages recus
    GET  /                        -> page HTML simple avec les messages
    DELETE /log                   -> vide l'historique

Depuis PowerShell (Windows):
    Invoke-WebRequest -Uri "http://<IP>:8765/log" -Method POST -Body "mon message"
"""

import argparse
import json
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

messages = []  # stockage en memoire


class RelayHandler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        # Surcharge pour un log plus lisible
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {self.client_address[0]} - {fmt % args}")

    # ------------------------------------------------------------------
    def do_POST(self):
        if self.path == "/log":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8", errors="replace").strip()
            entry = {"time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "from": self.client_address[0], "msg": body}
            messages.append(entry)
            print(f"\n{'='*60}")
            print(f"  [{entry['time']}] FROM {entry['from']}")
            print(f"  {body}")
            print(f"{'='*60}\n")
            self._send(200, "OK\n")
        else:
            self._send(404, "Not found\n")

    # ------------------------------------------------------------------
    def do_GET(self):
        if self.path in ("/log", "/log/"):
            payload = json.dumps(messages, ensure_ascii=False, indent=2)
            self._send(200, payload, content_type="application/json; charset=utf-8")
        elif self.path in ("/", "/index.html"):
            html = self._build_html()
            self._send(200, html, content_type="text/html; charset=utf-8")
        else:
            self._send(404, "Not found\n")

    # ------------------------------------------------------------------
    def do_DELETE(self):
        if self.path == "/log":
            messages.clear()
            self._send(200, "Cleared\n")
        else:
            self._send(404, "Not found\n")

    # ------------------------------------------------------------------
    def _send(self, code, body, content_type="text/plain; charset=utf-8"):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(data)

    def _build_html(self):
        rows = ""
        for m in reversed(messages):
            msg_escaped = m["msg"].replace("&", "&amp;").replace("<", "&lt;").replace("\n", "<br>")
            rows += f"<tr><td>{m['time']}</td><td>{m['from']}</td><td><pre>{msg_escaped}</pre></td></tr>"
        if not rows:
            rows = "<tr><td colspan='3' style='text-align:center;color:#888'>Aucun message</td></tr>"
        return f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="5">
  <title>Relay Server</title>
  <style>
    body {{ font-family: monospace; background:#111; color:#eee; padding:20px; }}
    h1 {{ color:#4af; }}
    table {{ width:100%; border-collapse:collapse; }}
    th {{ background:#222; padding:8px; text-align:left; color:#4af; }}
    td {{ padding:8px; border-bottom:1px solid #333; vertical-align:top; }}
    pre {{ margin:0; white-space:pre-wrap; color:#fa4; }}
    .clear {{ margin-top:10px; }}
    button {{ background:#a33; color:#fff; border:none; padding:6px 14px; cursor:pointer; border-radius:4px; }}
  </style>
</head>
<body>
  <h1>Relay Server <small style="font-size:.6em;color:#888">rafraichissement auto 5s</small></h1>
  <p>{len(messages)} message(s) recus &mdash;
     <a href="/log" style="color:#4af">JSON brut</a></p>
  <form class="clear" action="/log" method="post"
        onsubmit="fetch('/log',{{method:'DELETE'}});location.reload();return false;">
    <button type="submit">Vider l'historique</button>
  </form>
  <br>
  <table>
    <tr><th>Heure</th><th>Depuis</th><th>Message</th></tr>
    {rows}
  </table>
</body>
</html>"""


def main():
    parser = argparse.ArgumentParser(description="Relay server")
    parser.add_argument("--host", default="0.0.0.0", help="Adresse d'ecoute (defaut: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8765, help="Port (defaut: 8765)")
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), RelayHandler)
    print(f"Relay server en ecoute sur http://{args.host}:{args.port}")
    print(f"  POST /log   <- envoyer un message")
    print(f"  GET  /      <- interface HTML (auto-refresh 5s)")
    print(f"  GET  /log   <- historique JSON")
    print(f"  Ctrl+C pour arreter\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nArret.")


if __name__ == "__main__":
    main()

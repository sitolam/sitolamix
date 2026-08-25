#!/usr/bin/env python3
# Helium's Chrome Web Store update pings never carry a `prodversion` param
# (a bug in helium's build, not this config), and clients2.google.com
# silently answers "noupdate" for every extension when that param is
# missing. This proxy sits on loopback, adds prodversion before forwarding
# to the real endpoint, and streams the response straight back. Helium
# still downloads the actual .crx directly from Google's CDN — only the
# manifest ping goes through here.
import http.server
import urllib.error
import urllib.parse
import urllib.request

UPSTREAM = "https://clients2.google.com"
PRODVERSION = "151"
LISTEN = ("127.0.0.1", 8791)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
        if not any(key == "prodversion" for key, _ in query):
            query.append(("prodversion", PRODVERSION))
        url = f"{UPSTREAM}{parsed.path}?{urllib.parse.urlencode(query)}"

        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                body = resp.read()
                status = resp.status
                content_type = resp.headers.get("Content-Type", "text/xml")
        except urllib.error.HTTPError as e:
            body = e.read()
            status = e.code
            content_type = "text/xml"

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(LISTEN, Handler).serve_forever()

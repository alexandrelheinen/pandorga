#!/usr/bin/env python3
"""Serve a built site the way the public host does.

Python's stock http.server speaks HTTP/1.0 on one thread and sends HTML
and CSS uncompressed. Lighthouse then scores the same templates far below
the live site, which compresses responses and serves them concurrently.
"""

import gzip
import io
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

COMPRESSIBLE_EXACT = {
    "application/javascript",
    "application/json",
    "application/xml",
    "image/svg+xml",
}


def compressible(ctype):
    return ctype.startswith("text/") or ctype in COMPRESSIBLE_EXACT


class Handler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            index = os.path.join(path, "index.html")
            if os.path.isfile(index):
                path = index
            else:
                return super().send_head()

        ctype = self.guess_type(path)
        accept = self.headers.get("Accept-Encoding", "")
        if "gzip" not in accept or not compressible(ctype):
            return super().send_head()

        try:
            with open(path, "rb") as raw:
                data = raw.read()
        except OSError:
            self.send_error(404, "File not found")
            return None

        body = gzip.compress(data, compresslevel=6)
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Encoding", "gzip")
        self.send_header("Vary", "Accept-Encoding")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        return io.BytesIO(body)

    def log_message(self, fmt, *args):
        return


def main():
    if len(sys.argv) != 3:
        print("usage: lighthouse_server.py PORT DIRECTORY", file=sys.stderr)
        sys.exit(2)
    port = int(sys.argv[1])
    os.chdir(sys.argv[2])
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()

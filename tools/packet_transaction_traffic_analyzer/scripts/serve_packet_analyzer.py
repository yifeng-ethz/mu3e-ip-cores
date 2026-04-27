#!/usr/bin/env python3
"""Serve a generated packet analyzer directory over HTTP."""

from __future__ import annotations

import argparse
import os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve a packet analyzer output directory.")
    parser.add_argument("--dir", required=True, help="Generated analyzer directory")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host")
    parser.add_argument("--port", type=int, default=8765, help="Bind port")
    args = parser.parse_args()

    root = Path(args.dir).resolve()
    if not root.is_dir():
      raise SystemExit(f"Directory not found: {root}")

    os.chdir(root)
    server = ThreadingHTTPServer((args.host, args.port), SimpleHTTPRequestHandler)
    print(f"Serving {root} at http://{args.host}:{args.port}/")
    try:
      server.serve_forever()
    except KeyboardInterrupt:
      pass
    finally:
      server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

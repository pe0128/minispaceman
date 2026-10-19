"""Fetch only this platform's Godot templates from the official ZIP using HTTP ranges.

Avoid downloading the 1.2 GB archive's Android, iOS and Linux templates.
No third-party Python dependencies required.
"""
import argparse
import io
import os
from pathlib import Path
import time
import urllib.request
import zipfile

VERSION = "4.7.2"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"


class RangeReader(io.RawIOBase):
    def __init__(self, url):
        self.position = 0
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=45) as response:
            self.url = response.url
            self.length = int(response.headers["Content-Length"])

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset + (self.position if whence == 1 else self.length if whence == 2 else 0)
        return self.position

    def read(self, size=-1):
        if size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)
        if size <= 0:
            return b""
        request = urllib.request.Request(self.url, headers={
            "Range": f"bytes={self.position}-{self.position + size - 1}",
            "Accept-Encoding": "identity",
        })
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=90) as response:
                    if response.status != 206:
                        raise RuntimeError("Server does not support partial download; install templates in Godot instead")
                    data = response.read(size)
                    if len(data) != size:
                        raise IOError("Incomplete template range response")
                self.position += len(data)
                return data
            except (OSError, RuntimeError):
                if attempt == 3:
                    raise
                time.sleep(attempt + 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["windows", "macos"], required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.output
    if root is None:
        base = Path(os.environ["APPDATA"]) if args.platform == "windows" else Path.home() / "Library/Application Support"
        root = base / "Godot/export_templates" / f"{VERSION}.stable"
    wanted = {"version.txt", "windows_debug_x86_64.exe", "windows_release_x86_64.exe"} if args.platform == "windows" else {"version.txt", "macos.zip"}
    root.mkdir(parents=True, exist_ok=True)
    if all((root / name).exists() for name in wanted):
        print(f"Templates already installed: {root}")
        return
    with zipfile.ZipFile(RangeReader(URL)) as archive:
        for member in archive.infolist():
            name = Path(member.filename).name
            if name in wanted:
                target = root / name
                if not target.exists():
                    print(f"Fetching {name} ({member.compress_size / 1024**2:.1f} MiB compressed)", flush=True)
                    payload = archive.read(member)
                    temporary = target.with_suffix(target.suffix + ".tmp")
                    temporary.write_bytes(payload)
                    temporary.replace(target)
    missing = [name for name in wanted if not (root / name).exists()]
    if missing:
        raise RuntimeError(f"Missing template entries: {missing}")
    print(f"Installed: {root}")


if __name__ == "__main__":
    main()

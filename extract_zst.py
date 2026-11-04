#!/usr/bin/env python3
"""Fallback extractor for .tar.zst archives using the python 'zstandard' module.

Usage: extract_zst.py <archive.tar.zst> <dest_dir>
Used by install.sh only when neither `tar --zstd` nor the `zstd` binary exists.
"""
import sys
import tarfile


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, dest = sys.argv[1], sys.argv[2]
    try:
        import zstandard
    except ImportError:
        print("ERROR: python module 'zstandard' is not installed", file=sys.stderr)
        return 2
    dctx = zstandard.ZstdDecompressor()
    with open(src, "rb") as fh, dctx.stream_reader(fh) as reader, \
            tarfile.open(fileobj=reader, mode="r|") as tf:
        try:
            tf.extractall(dest, filter="data")
        except TypeError:
            tf.extractall(dest)
    return 0


if __name__ == "__main__":
    sys.exit(main())

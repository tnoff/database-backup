#!/usr/bin/env python3
"""Take a consistent online copy of a live SQLite database.

Usage: sqlite_backup.py <source.db> <destination.db>

Uses SQLite's online-backup API, so it is safe against a database that another
process is writing to (WAL or not). The source is opened read-only: a wrong path
is an error, not a silently created empty database. The copy is checked before
the script reports success, and any failure removes the partial copy and exits
non-zero so nothing bad is ever uploaded.
"""
import os
import sqlite3
import sys
from urllib.parse import quote


def backup(source_path, destination_path):
    """Copy source_path to destination_path and verify the copy."""
    if not os.path.isfile(source_path):
        raise RuntimeError(f'source database not found: {source_path}')
    source = sqlite3.connect(f'file:{quote(source_path)}?mode=ro', uri=True)
    destination = sqlite3.connect(destination_path)
    try:
        source.backup(destination)
        # One self-contained file: no -wal/-shm to ship or lose on restore.
        destination.execute('PRAGMA journal_mode=DELETE')
        result = destination.execute('PRAGMA integrity_check').fetchall()
        if result != [('ok',)]:
            raise RuntimeError(f'integrity_check failed on the copy: {result}')
        tables = destination.execute(
            "SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0]
        if tables == 0:
            raise RuntimeError('the copy has no tables; refusing to treat it as a backup')
    finally:
        source.close()
        destination.close()


def main(argv):
    """Entry point; returns the process exit code."""
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        backup(argv[1], argv[2])
    except (RuntimeError, sqlite3.Error) as error:
        print(f'sqlite backup failed: {error}', file=sys.stderr)
        if os.path.exists(argv[2]):
            os.remove(argv[2])
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

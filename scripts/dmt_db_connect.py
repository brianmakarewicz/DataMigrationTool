#!/usr/bin/env python
"""Hardened python-oracledb connect shared by the CI scripts.

Why: scripts/dmt_regression_run.py hung forever twice (local runs 293 and
338) after the pipeline run had finished. oracledb.connect() was called with
no connect timeout, so a stalled TCP connect / TLS / auth handshake could block
indefinitely, and call_timeout only protects round trips made AFTER connect.

connect_with_retry() closes that gap in three layers:
  1. tcp_connect_timeout (thin mode, python-oracledb 3.x) bounds the socket
     connect, and expire_time enables keepalive probes so a dead peer is
     noticed on a long-lived connection;
  2. the whole connect runs in a daemon thread with an overall deadline, so a
     hang anywhere in the handshake (not just the socket connect) is abandoned
     instead of blocking the caller;
  3. a failed or timed-out attempt is retried with exponential backoff.
Every returned connection carries a finite call_timeout; callers must never set
call_timeout = 0 (0 means "wait forever").
"""
import threading
import time

import oracledb

TCP_CONNECT_TIMEOUT_S = 30      # socket connect bound (thin mode)
EXPIRE_TIME_MIN = 2             # keepalive probe interval on idle connections
CONNECT_DEADLINE_S = 90         # overall bound on one connect attempt (handshake incl.)
CONNECT_ATTEMPTS = 4
BACKOFF_S = 5                   # 5, 10, 20 s between attempts
DEFAULT_CALL_TIMEOUT_MS = 120_000


class ConnectTimeout(Exception):
    """One connect attempt exceeded CONNECT_DEADLINE_S."""


def _connect_once(connect_fn, deadline_s, kwargs):
    box = {}

    def run():
        try:
            box['conn'] = connect_fn(**kwargs)
        except BaseException as e:   # noqa: BLE001 — re-raised in the caller
            box['err'] = e

    t = threading.Thread(target=run, name='dmt-db-connect', daemon=True)
    t.start()
    t.join(deadline_s)
    if t.is_alive():
        # Abandon the stuck attempt (daemon thread, cannot block exit). If it
        # completes later, its connection is simply garbage-collected.
        raise ConnectTimeout(f"connect did not complete within {deadline_s}s")
    if 'err' in box:
        raise box['err']
    return box['conn']


def connect_with_retry(*, call_timeout_ms=DEFAULT_CALL_TIMEOUT_MS,
                       attempts=CONNECT_ATTEMPTS, backoff_s=BACKOFF_S,
                       deadline_s=CONNECT_DEADLINE_S, connect_fn=None,
                       sleep=time.sleep, log=print, **connect_kwargs):
    """oracledb.connect(**connect_kwargs) with connect timeouts and retries.

    Returns a connection whose call_timeout is call_timeout_ms (must be > 0).
    Raises the last error after `attempts` failed attempts."""
    if not call_timeout_ms or call_timeout_ms <= 0:
        raise ValueError("call_timeout_ms must be a positive number of ms (0 = wait forever)")
    connect_fn = connect_fn or oracledb.connect
    connect_kwargs.setdefault('tcp_connect_timeout', TCP_CONNECT_TIMEOUT_S)
    connect_kwargs.setdefault('expire_time', EXPIRE_TIME_MIN)
    last = None
    for i in range(1, attempts + 1):
        try:
            conn = _connect_once(connect_fn, deadline_s, connect_kwargs)
            conn.call_timeout = call_timeout_ms
            return conn
        except (oracledb.Error, OSError, ConnectTimeout) as e:
            last = e
            if i == attempts:
                break
            wait = backoff_s * (2 ** (i - 1))
            log(f"  [db] connect attempt {i}/{attempts} failed ({str(e)[:160]}); "
                f"retrying in {wait}s")
            sleep(wait)
    raise last


def retry_db(fn, *, attempts=3, backoff_s=15, what='database call',
             sleep=time.sleep, log=print):
    """Run fn(); on a DB error / timeout retry up to `attempts` times total."""
    last = None
    for i in range(1, attempts + 1):
        try:
            return fn()
        except (oracledb.Error, OSError, ConnectTimeout) as e:
            last = e
            if i == attempts:
                break
            wait = backoff_s * (2 ** (i - 1))
            log(f"  [db] {what} failed (attempt {i}/{attempts}: {str(e)[:160]}); "
                f"retrying in {wait}s")
            sleep(wait)
    raise last

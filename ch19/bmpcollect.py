#!/usr/bin/env python3
"""Chapter 19: a BMP collector. The switches' FRR streams every BGP peer-up,
peer-down, and route update to this station over BMP (RFC 7854), so the RIB's
history is visible without logging into a switch. Each route-monitoring
message carries a BGP UPDATE; this decodes the announced and withdrawn
prefixes (classic and MP-BGP, since the fabric carries IPv4 over unnumbered
with extended next-hop) and appends one JSON event per change. Answering
"which prefixes churned during the incident window" is then a read of the log.

Runs on a fabric-reachable host (a server), since the switches reach the
collector through the fabric, not the management network."""
import socket, struct, json, sys, threading, time, os

PORT = int(os.environ.get("BMP_PORT", "1790"))
OUT = os.environ.get("BMP_OUT", "/tmp/bmp-events.jsonl")
TYPES = {0: "route-monitoring", 1: "stats", 2: "peer-down",
         3: "peer-up", 4: "init", 5: "term", 6: "route-mirror"}
lock = threading.Lock()

import ipaddress
def peeraddr(b):  # 16-byte BMP peer address: v4-mapped, all-zero, or IPv6 link-local
    if b[:12] == b"\x00" * 12:
        return ".".join(str(x) for x in b[-4:])
    if b[:12] == b"\x00" * 10 + b"\xff\xff":
        return ".".join(str(x) for x in b[-4:])
    return str(ipaddress.IPv6Address(bytes(b)))

def prefixes(data, off, end):
    out = []
    while off < end:
        bits = data[off]; off += 1
        nb = (bits + 7) // 8
        raw = data[off:off + nb] + b"\x00" * (4 - nb); off += nb
        out.append(f"{'.'.join(str(x) for x in raw[:4])}/{bits}")
    return out, off

def parse_update(u):
    """Return (announced, withdrawn) IPv4 prefixes from a BGP UPDATE PDU."""
    ann, wd = [], []
    off = 19  # 16 marker + 2 length + 1 type
    wlen = struct.unpack("!H", u[off:off + 2])[0]; off += 2
    w, _ = prefixes(u, off, off + wlen); wd += w; off += wlen
    palen = struct.unpack("!H", u[off:off + 2])[0]; off += 2
    pend = off + palen
    while off < pend:
        flags = u[off]; atype = u[off + 1]; off += 2
        if flags & 0x10:  # extended length
            alen = struct.unpack("!H", u[off:off + 2])[0]; off += 2
        else:
            alen = u[off]; off += 1
        aval = u[off:off + alen]; aend = off + alen
        if atype == 14:  # MP_REACH_NLRI
            afi = struct.unpack("!H", aval[0:2])[0]; safi = aval[2]
            nhl = aval[3]; p = 4 + nhl + 1  # afi,safi,nhlen,nexthop,reserved
            if afi == 1 and safi == 1:
                mp, _ = prefixes(aval, p, len(aval)); ann += mp
        elif atype == 15:  # MP_UNREACH_NLRI
            afi = struct.unpack("!H", aval[0:2])[0]; safi = aval[2]
            if afi == 1 and safi == 1:
                mp, _ = prefixes(aval, 3, len(aval)); wd += mp
        off = aend
    a, _ = prefixes(u, off, len(u)); ann += a  # classic NLRI
    return ann, wd

def emit(ev):
    with lock:
        with open(OUT, "a") as f:
            f.write(json.dumps(ev) + "\n")
    print(json.dumps(ev), flush=True)

def handle(conn, addr):
    buf = b""
    while True:
        d = conn.recv(65535)
        if not d: break
        buf += d
        while len(buf) >= 6:
            mlen = struct.unpack("!I", buf[1:5])[0]; mtype = buf[5]
            if len(buf) < mlen: break
            msg, buf = buf[:mlen], buf[mlen:]
            now = round(time.time(), 3)
            if mtype in (0, 2, 3):  # has per-peer header
                pph = msg[6:48]
                peer = peeraddr(pph[10:26]); pas = struct.unpack("!I", pph[26:30])[0]
                if mtype == 3:
                    emit({"t": now, "event": "peer-up", "peer": peer, "as": pas})
                elif mtype == 2:
                    emit({"t": now, "event": "peer-down", "peer": peer, "as": pas})
                else:  # route-monitoring
                    upd = msg[48:]
                    try:
                        ann, wd = parse_update(upd)
                    except Exception as e:
                        ann, wd = [], []
                    if ann or wd:
                        emit({"t": now, "event": "update", "peer": peer,
                              "announce": ann, "withdraw": wd})
    conn.close()

s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", PORT)); s.listen(16)
open(OUT, "w").close()
print(f"BMP collector on :{PORT}, events -> {OUT}", flush=True)
while True:
    conn, addr = s.accept()
    threading.Thread(target=handle, args=(conn, addr), daemon=True).start()

#!/usr/bin/env bash
# Chapter 20 worked example: a compromised host attacks the fabric through its
# BGP session, and the per-peer controls chapter 9 already built stop it. The
# import filter drops a default-route hijack and a bogus prefix; the
# maximum-prefix limit tears the session down under a prefix flood. Same
# session, hardened, holds.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/redteam}; mkdir -p "$OUT"
Sv(){ sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 cumulus@clab-${LAB}-${LEAF} "sudo vtysh -c \"$1\"" 2>/dev/null; }
Hv(){ docker exec clab-${LAB}-${HOST} vtysh -c "$1" 2>/dev/null; }
pfxrcd(){ Sv "show bgp ipv4 unicast summary" | grep "$HOST" | awk '{print $(NF-2)}'; }

{
echo "=== The compromised host advertises a default route, a bogus prefix, and its one legit /32 ==="
Hv "configure terminal
ip route 0.0.0.0/0 Null0
router bgp 65500
 address-family ipv4 unicast
  redistribute static
 exit-address-family
end" >/dev/null
Sv "clear bgp ipv4 unicast swp1" >/dev/null
sleep 18
echo "--- the leaf RECEIVES all three (an unhardened leaf installs whatever it receives) ---"
Sv "show bgp ipv4 unicast neighbors swp1 received-routes" | grep -oE "0.0.0.0/0|10.66.66.0/24|172.16.101.1/32" | sort -u | awk '{print "    received: "$1}'
echo "--- the hardened leaf INSTALLS only the /32 the host may originate ---"
for p in 0.0.0.0/0 10.66.66.0/24 172.16.101.1/32; do
  printf "    %-16s installed: %s\n" "$p" "$(Sv "show bgp ipv4 unicast $p" | grep -c "from $HOST")"
done
echo "    accepted-prefix count on the session (PfxRcd): $(pfxrcd)"
echo "  The default-route hijack and the bogus prefix are dropped at the door."
echo
echo "=== The compromised host floods /32s to exhaust the leaf's RIB ==="
CMD="configure terminal"
for i in 10 11 12 13 14 15 16 17; do CMD="$CMD
interface lo
 ip address 172.16.101.$i/32"; done
Hv "$CMD
end" >/dev/null
sleep 6
echo "    session state under the flood: $(Sv "show bgp ipv4 unicast summary" | grep "$HOST" | awk '{print $(NF-2)" "$(NF-1)}')"
echo "  maximum-prefix tears the session down (Idle, PfxCt) instead of letting the flood in."
echo
echo "=== cleanup: the fabric returns to one accepted /32 ==="
CMD2="configure terminal"
for i in 10 11 12 13 14 15 16 17; do CMD2="$CMD2
interface lo
 no ip address 172.16.101.$i/32"; done
Hv "$CMD2
end" >/dev/null
Hv "configure terminal
no ip route 0.0.0.0/0 Null0
router bgp 65500
 address-family ipv4 unicast
  no redistribute static
 exit-address-family
end" >/dev/null
Sv "clear bgp ipv4 unicast swp1" >/dev/null
sleep 14
echo "    accepted /32 after cleanup: $(pfxrcd)"
} | tee "$OUT/evidence.txt"

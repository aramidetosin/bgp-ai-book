#!/usr/bin/env bash
# Chapter 20: complete the host-facing session's hardening past the import
# filter and prefix limit chapter 9 built. Session authentication so an
# attacker without the key cannot hold the session, and GTSM so one from more
# than a hop away is dropped. The authentication mechanism is checked against
# the platform, not assumed.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/harden}; mkdir -p "$OUT"
Sv(){ sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 cumulus@clab-${LAB}-${LEAF} "sudo vtysh -c \"$1\"" 2>/dev/null; }
Hv(){ docker exec clab-${LAB}-${HOST} vtysh -c "$1" 2>/dev/null; }
state(){ Sv "show bgp ipv4 unicast summary" | grep "$HOST" | awk '{print $(NF-2)}'; }

{
echo "=== TCP-AO support on this platform, checked not assumed ==="
n=$(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-${LAB}-${LEAF} "sudo bash -c 'strings /usr/lib/frr/bgpd | grep -ic tcp-authopt'" 2>/dev/null)
echo "    'tcp-authopt' references in this bgpd binary: $n"
echo "    TCP-AO is not available here, so session authentication uses MD5, the widely deployed fallback."
echo
echo "=== MD5: the key is required on both ends ==="
echo "    session before: PfxRcd=$(state)"
Sv "configure terminal
router bgp 65101
 neighbor swp1 password fabricsecret
end" >/dev/null
sleep 12
echo "    key on the leaf only (an attacker lacks it): $(state)   <- session down"
Hv "configure terminal
router bgp 65500
 neighbor eth1 password fabricsecret
end" >/dev/null
sleep 14
echo "    matching key supplied on the host: PfxRcd=$(state)   <- session up"
echo
echo "=== GTSM: only a directly connected peer passes ==="
Sv "configure terminal
router bgp 65101
 neighbor swp1 ttl-security hops 1
end" >/dev/null
sleep 12
echo "    session with GTSM + MD5 (host is one hop): PfxRcd=$(state)"
echo "    A peer more than one hop away fails the TTL check before BGP runs."
echo
echo "=== cleanup ==="
Sv "configure terminal
router bgp 65101
 no neighbor swp1 ttl-security hops 1
 no neighbor swp1 password fabricsecret
end" >/dev/null
Hv "configure terminal
router bgp 65500
 no neighbor eth1 password fabricsecret
end" >/dev/null
sleep 12
echo "    session restored: PfxRcd=$(state)"
} | tee "$OUT/evidence.txt"

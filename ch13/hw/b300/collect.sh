#!/usr/bin/env bash
# Chapter 13: read-only collector for the B300 GPU nodes' host-side RoCE
# configuration. Run from a host that can reach the B300 data-path IPs.
# READ-ONLY: every command reads (sysfs, ibv, dcb show, ethtool show).
# Nothing here configures the NIC, loads a module, or starts traffic.
#
#   SSHPASS='<password>' ./collect.sh <host-ip> [netdev] [rdma-dev]
#
# Writes the same fields this chapter quotes. The representative NIC is a
# 400G RoCE-capable ConnectX port; override netdev/rdma-dev for your node.
set -uo pipefail
IP=${1:?usage: collect.sh <host-ip> [netdev] [rdma-dev]}
ND=${2:-enp115s0f0np0}
IB=${3:-mlx5_0}
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 oiadmin@${IP}"

${SSH} "
echo '# B300 host RoCE config (read-only), chapter 13'
echo -n 'host: '; hostname; echo -n 'os: '; grep PRETTY /etc/os-release | cut -d= -f2; echo -n 'kernel: '; uname -r
echo; echo '## representative 400G RoCE NIC: ${ND} (${IB})'
echo -n 'speed_Mb: '; cat /sys/class/net/${ND}/speed 2>/dev/null
echo 'GID types (v2 = RoCEv2):'; for g in 0 1; do echo \"  gid[\$g]=\$(cat /sys/class/infiniband/${IB}/ports/1/gid_attrs/types/\$g 2>/dev/null)\"; done
echo -n 'roce_rp enable p0-7: '; for p in 0 1 2 3 4 5 6 7; do printf %s \$(cat /sys/class/net/${ND}/ecn/roce_rp/enable/\$p 2>/dev/null); done; echo
echo -n 'roce_np enable p0-7: '; for p in 0 1 2 3 4 5 6 7; do printf %s \$(cat /sys/class/net/${ND}/ecn/roce_np/enable/\$p 2>/dev/null); done; echo
echo \"cnp_dscp: \$(cat /sys/class/net/${ND}/ecn/roce_np/cnp_dscp 2>/dev/null)  cnp_802p_prio: \$(cat /sys/class/net/${ND}/ecn/roce_np/cnp_802p_prio 2>/dev/null)  min_time_between_cnps: \$(cat /sys/class/net/${ND}/ecn/roce_np/min_time_between_cnps 2>/dev/null)\"
echo -n 'PFC: '; sudo dcb pfc show dev ${ND} 2>/dev/null | grep prio-pfc
echo 'DSCP->prio (CS3 block = RoCE data, CS6 = CNP):'; sudo dcb app show dev ${ND} 2>/dev/null | tr ' ' '\n' | grep -E 'CS3|AF3|^2[4-9]:|3[01]:|CS6|48:' | tr '\n' ' '; echo
echo 'health counters (should stay zero; the alert is the first non-zero):'
for c in out_of_sequence packet_seq_err roce_adp_retrans local_ack_timeout_err np_cnp_sent np_ecn_marked_roce_packets rp_cnp_handled; do
  echo \"  \$c=\$(cat /sys/class/infiniband/${IB}/ports/1/hw_counters/\$c 2>/dev/null)\"
done
echo -n 'link_layer ${IB}: '; cat /sys/class/infiniband/${IB}/ports/1/link_layer 2>/dev/null
"

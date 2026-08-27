#!/usr/bin/env bash
# Start the three Kubernetes node containers before containerlab wires
# them in. kindest/node ships systemd, containerd, kubeadm, and the
# preloaded images for its Kubernetes version, which keeps the cluster
# build off the lab containers' unreliable NAT path entirely.
set -euo pipefail

LAB=bgpbook-ch10
IMG=$(awk '/k8s_image:/{print $2}' spec.yml)

docker image inspect "${IMG}" >/dev/null 2>&1 || docker pull "${IMG}"

for n in node01 node02 node03; do
  name=${n}
  docker inspect "${name}" >/dev/null 2>&1 && continue
  docker run -d --name "${name}" --hostname "${n}" \
    --privileged --restart=no \
    --tmpfs /tmp --tmpfs /run \
    -v /var -v /lib/modules:/lib/modules:ro \
    "${IMG}" >/dev/null
  echo "  ${name} running"
done

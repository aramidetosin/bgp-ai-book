#!/usr/bin/env bash
# Undo break14a.sh: reapply the control-class QoS on the array uplinks.
set -uo pipefail
exec ./qos.sh

#!/usr/bin/env bash
# Shared Palo Alto API helpers for the chapter 12 scripts.
# Usage: source pa.sh; pa_key <mgmt-ip>; pa_op <mgmt-ip> "<xml-cmd>"
PA_USER=admin
PA_PASS=Admin@123

pa_key() {
  curl -sk "https://$1/api/?type=keygen&user=${PA_USER}&password=${PA_PASS}" \
    | sed -n 's|.*<key>\(.*\)</key>.*|\1|p'
}

pa_op() { # ip, cmd-xml
  local key; key=$(pa_key "$1")
  curl -sk "https://$1/api/" --data-urlencode "type=op" \
    --data-urlencode "key=${key}" --data-urlencode "cmd=$2"
}

pa_state() { # ip -> local HA state one-liner
  pa_op "$1" "<show><high-availability><state/></high-availability></show>" \
    | sed -n 's|.*<state>\([a-z-]*\)</state>.*|\1|p' | head -1
}

#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

exec sleep infinity

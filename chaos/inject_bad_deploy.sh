#!/usr/bin/env bash
# Simulates a broken deployment by building the app with FORCE_FAIL=true,
# so the health gate fails and the rollback path runs end-to-end.
#
# Usage: ./chaos/inject_bad_deploy.sh v2-broken
set -euo pipefail

VERSION="${1:-v2-broken}"

echo "Injecting a failing deployment as version: $VERSION"
ansible-playbook -i ../ansible/inventory.ini ../ansible/deploy.yml \
  -e "target_version=$VERSION" \
  -e "force_fail=true"

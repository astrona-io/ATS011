#!/usr/bin/env bash
set -euo pipefail

for n in staging production sandbox; do kubectl create namespace $n --dry-run=client -o yaml | kubectl apply -f -; done

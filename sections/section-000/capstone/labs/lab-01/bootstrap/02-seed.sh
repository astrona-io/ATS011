#!/usr/bin/env bash
set -euo pipefail

for n in apps legacy; do kubectl create namespace $n --dry-run=client -o yaml | kubectl apply -f -; done

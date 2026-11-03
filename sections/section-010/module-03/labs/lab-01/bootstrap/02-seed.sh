#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace anchors --dry-run=client -o yaml | kubectl apply -f -

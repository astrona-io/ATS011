#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace anchor-lab --dry-run=client -o yaml | kubectl apply -f -

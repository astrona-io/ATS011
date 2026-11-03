#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace cel-lab --dry-run=client -o yaml | kubectl apply -f -

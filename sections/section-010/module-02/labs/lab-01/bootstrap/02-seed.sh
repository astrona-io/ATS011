#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace shop --dry-run=client -o yaml | kubectl apply -f -

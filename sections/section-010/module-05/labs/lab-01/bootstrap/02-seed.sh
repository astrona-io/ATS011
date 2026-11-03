#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace assert-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount app-sa -n assert-lab --dry-run=client -o yaml | kubectl apply -f -

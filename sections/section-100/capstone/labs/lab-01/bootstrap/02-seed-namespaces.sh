#!/usr/bin/env bash
set -euo pipefail

echo "Seeding namespaces for the cleanup capstone..."
kubectl create namespace capstone-cleanup --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace capstone-keep    --dry-run=client -o yaml | kubectl apply -f -

echo "Namespaces ready: capstone-cleanup (sweep target), capstone-keep (must never be touched)."

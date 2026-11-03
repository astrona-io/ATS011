# Question

Kyverno is installed and the namespace `image-lab` exists. Write a `ClusterPolicy` named `image-source-rules` with `validationFailureAction: Enforce` and `background: false`. It must contain two rules that match Pods in `image-lab`, and both must use the `images` context variable:

1. A rule named `allowed-registries` that denies a Pod when any container image comes from a registry other than `docker.io` or `ghcr.io`. An image with no registry counts as `docker.io`.
2. A rule named `no-latest-tag` that denies a Pod when any container image uses the `latest` tag. An image with no tag counts as `latest`.

Requirements:

- A Pod using `nginx:1.27` or `ghcr.io/example/app:1.0` is admitted.
- A Pod using `quay.io/example/app:1.0`, `nginx` or `nginx:latest` is rejected.
- A Deployment with the same images is admitted or rejected in the same way. Do not write separate Deployment rules.
- Nothing in the policy may need a signature or access to a registry.

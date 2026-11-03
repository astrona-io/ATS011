# Question

Kyverno is installed and the namespace `mutate-lab` exists. Write a `ClusterPolicy` named `internal-registry` with `background: false` and one mutate rule for Pods in `mutate-lab`:

1. Use `mutate.foreach` over `request.object.spec.containers` and prefix every container image with `registry.internal/`. `nginx:1.27` becomes `registry.internal/nginx:1.27`.
2. Guard the loop with a precondition so that an image that already starts with `registry.internal/` is left as it is. Re-submitting a mutated Pod must never produce `registry.internal/registry.internal/...`.
3. Every container in a multi-container Pod must be rewritten.

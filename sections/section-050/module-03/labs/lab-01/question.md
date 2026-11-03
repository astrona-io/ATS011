# Question

Kyverno is installed. The namespace `shared-config` holds three ConfigMaps: `app-settings` and `feature-flags` are labelled `share=true`, and `private-notes` has no label. The background controller is allowed to manage ConfigMaps.

Write two `ClusterPolicy` objects.

**Policy `share-config`** with one generate rule that triggers on Namespaces labelled `needs-shared=true`:

1. Use `cloneList` to clone the ConfigMaps from `shared-config` into the new namespace.
2. Only ConfigMaps labelled `share=true` may be cloned. `private-notes` must not appear.
3. Keep the copies in sync with their sources.

**Policy `env-configmaps`** with one generate rule that triggers on Namespaces labelled `env-set=true`. Such a namespace carries an annotation `envs` holding a comma-separated list such as `dev,test,legacy`:

1. Use `generate.foreach` to create one ConfigMap in the namespace for every element of that list.
2. Name each ConfigMap `env-<element>`, for example `env-dev`, and give it a data key `environment` set to the element.
3. Skip the element `legacy`: no ConfigMap is generated for it.

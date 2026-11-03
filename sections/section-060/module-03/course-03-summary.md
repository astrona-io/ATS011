# Summary

Kyverno builds an `images` variable for every Pod and pod controller. It groups the images into containers, init containers and ephemeral containers, and keys each entry by container name. Each entry carries the registry, path, name, tag, digest and the original reference. A missing registry becomes `docker.io` and a missing tag becomes `latest`. A digest-pinned image has a digest and no tag.

A rule reads these parts with JMESPath. A wildcard query returns one value per container, and a set operator such as `AnyNotIn` or `AnyIn` turns that list into a single condition. This gives short rules for an allowed-registry list or a ban on the `latest` tag. None of it needs a signature or access to a registry. Because Kyverno generates rules for pod controllers, a rule written for Pods also applies to a Deployment and reads the images from its pod template.

For a custom resource Kyverno does not know where the image is. The `imageExtractors` field of a rule maps a kind to one or more extractors. Each has a path, and optionally a value field, a key field and a JMESPath expression that cleans the string. Extractors add kinds. They do not change how Pods are handled.

Key facts:

- `images` has `containers`, `initContainers` and `ephemeralContainers`, keyed by container name.
- An empty registry is `docker.io` and an empty tag is `latest`.
- `AnyNotIn` denies when any element is outside the allow list.
- `imageExtractors` is only needed for kinds that are not Pods or pod controllers.

<!-- astrona:playground:destroy -->

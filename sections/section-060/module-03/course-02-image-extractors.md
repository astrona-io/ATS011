# Part 2: Image Extractors

## What the default covers

Kyverno knows where images live in a Pod and in the pod controllers: the containers, init containers and ephemeral containers of the pod spec, or of the pod template. That is why `images` works for those kinds without any setup.

A custom resource keeps its image somewhere else, in a field only its author knows. A Tekton `TaskRun` lists step images under its status. A KubeVirt `DataVolume` holds an image URL under `spec.source`. Kyverno cannot guess those paths, so a rule that matches such a kind sees no images until you describe where to look.

## imageExtractors

`imageExtractors` is a field of the rule. It maps a **kind** to a list of extractors. Each extractor points at one place in the resource:

```yaml
rules:
  - name: check-task-images
    match:
      any:
        - resources:
            kinds: ["tekton.dev/v1beta1/TaskRun"]
    imageExtractors:
      TaskRun:
        - name: taskrunstatus
          path: /status/taskSpec/steps/*
          value: image
          key: name
```

| Field | Meaning |
| :--- | :--- |
| `path` | A slash-separated path to the object or list that holds the images. A `*` stands for every item of a list. |
| `value` | The field inside each object that holds the image reference. |
| `key` | The field inside each object that gives the entry its key, the way a container name does for a Pod. |
| `name` | A name for the extractor. It groups the extracted images in the same way `containers` groups Pod images. |
| `jmesPath` | An optional expression that rewrites the extracted string before use. |

In the example, `path` selects every step of the task, `value: image` reads the image from each step, and `key: name` keys each entry by the step name.

When the field holds the image string directly, `value` and `key` are not needed. A KubeVirt `DataVolume` stores the reference in `spec.source.registry.url`, written with a `docker://` prefix. The extractor trims the prefix with `jmesPath`:

```yaml
imageExtractors:
  DataVolume:
    - path: /spec/source/registry/url
      jmesPath: "trim_prefix(@, 'docker://')"
```

## Where extractors are used

Extractors serve the rules that work on image references. The best known is `verifyImages`, which needs to know which images to verify in a custom resource. The extractor is the reason a signature policy can cover a `TaskRun` at all.

An extractor is not a way to turn off or to change the default Pod extraction. It adds knowledge about kinds Kyverno does not know. For Pods and pod controllers you write nothing.

> [!NOTE]
> The playground has no operator that installs custom resources like `TaskRun`, and the extractor examples are drawn from the Kyverno documentation, not from a transcript. To try one, install a small CRD of your own with an image field, add an extractor for it, and write a rule that reads the extracted image.

## Choosing the right tool

| You want to check | Use |
| :--- | :--- |
| Registry, tag or digest of a Pod image | `images` variable, no setup |
| The same on a Deployment or StatefulSet | The same rule, through auto-generation |
| An image in a custom resource | `imageExtractors` for that kind |
| That an image is signed | `verifyImages` |

> [!WARNING]
> **Common pitfalls**
>
> - **Expecting `images` for a custom resource without an extractor.** Kyverno extracts only what it knows or what you describe.
> - **A wrong `path`.** The path starts at the resource root and uses slashes, for example `/spec/source/registry/url`. A path that misses returns nothing, and the rule then checks nothing.
> - **Forgetting the prefix of a URL field.** An image stored as `docker://registry/app:1` is not a valid reference until `jmesPath` trims the prefix.
> - **Keying the extractor by the wrong kind.** The map key under `imageExtractors` is the kind of the resource the rule matches.

## Your mission: Image Extraction Lab

You can now read the `images` variable, write JMESPath over it and describe where a custom resource keeps its images. The mission asks you to write one policy that restricts image registries and blocks the `latest` tag, and to make it work on both Pods and Deployments.

Pause the playground, start the lab, and submit your work as often as you like:

```sh
astrona stop ats-011-playground-0603
astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-060/module-03/labs/lab-01
astrona submit -c sections/section-060/module-03/labs/lab-01
```

When the lab passes, remove it and return to the playground:

```sh
astrona destroy ats-011-lab-063
astrona start ats-011-playground-0603
```

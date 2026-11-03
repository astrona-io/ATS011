# Part 2: generate foreach: One Resource per Element

## When the count is not fixed

`data` generates one resource. `clone` copies one. `cloneList` copies many, but only things that already exist. What if the trigger itself says how many resources to make?

Suppose a namespace carries the annotation `envs: "dev,test,prod"` and you want one ConfigMap for each environment. `generate.foreach` loops over a list and runs a generate step for every element.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: env-configmaps
spec:
  rules:
    - name: one-per-env
      match:
        any:
          - resources:
              kinds:
                - Namespace
              selector:
                matchLabels:
                  env-set: "true"
      generate:
        synchronize: true
        foreach:
          - list: "request.object.metadata.annotations.envs | split(@, ',')"
            context:
              - name: env
                variable:
                  jmesPath: element
            preconditions:
              all:
                - key: "{{ env }}"
                  operator: NotEquals
                  value: legacy
            apiVersion: v1
            kind: ConfigMap
            name: "env-{{ env }}"
            namespace: "{{ request.object.metadata.name }}"
            data:
              data:
                environment: "{{ env }}"
```

## Reading it

* `list` is a JMESPath expression written **without** curly braces. Here `split(@, ',')` turns the annotation string into a list of strings.
* Inside the loop, `element` is the current item and `elementIndex` is its position, starting at 0. Both exist only inside `foreach`.
* `context` gives the element a readable name. Here `env` is set to `element`, so the rest of the entry can write `{{ env }}`.
* `preconditions` run once per element. An element that fails them is skipped, and the loop moves on. The example skips the element `legacy`.
* The generate fields (`apiVersion`, `kind`, `name`, `namespace`, and `data` or `clone`) sit directly inside the foreach entry. They are evaluated per element, so `name` can use `env` and produce `env-dev`, `env-test`, `env-prod`.

Unlike `cloneList`, the `synchronize`, `generateExisting` and `orphanDownstreamOnPolicyDelete` fields stay at the `generate` level, beside `foreach`, not inside the entry.

With the annotation `envs: "dev,test,legacy"` the rule creates `env-dev` and `env-test` and nothing for `legacy`.

> [!TIP]
> **Try it — one ConfigMap per environment**
>
> <!-- astrona:playground:renew -->
> Save the policy as `env-configmaps.yaml`, then:
>
> ```sh
> kubectl apply -f env-configmaps.yaml
> kubectl create namespace team-y --dry-run=client -o yaml | kubectl label --local -f - env-set=true -o yaml | kubectl annotate --local -f - envs=dev,test,legacy -o yaml | kubectl apply -f -
> kubectl get configmap -n team-y
> kubectl get configmap env-test -n team-y -o jsonpath='{.data.environment}'
> ```
>
> Expect `env-dev` and `env-test` in `team-y`, no `env-legacy`, and the last command to print `test`. Poll if the first read is empty.

## Choosing the right tool

* One resource with fixed content: `generate.data`.
* One existing object to copy: `generate.clone`.
* Several existing objects to copy, found by kind and label: `generate.cloneList`.
* A number of resources decided by the trigger or by a list: `generate.foreach`.

A foreach entry can itself use `clone` instead of `data` to copy a source for every element.

> [!NOTE]
> Changing the foreach `name` pattern in a policy that has already generated resources does not rename them. Kyverno does not update a resource that was created under an old name, so plan names before the first rollout.

## Common pitfalls

> [!WARNING]
> - **Wrapping `list` in `{{ }}`.** It is a bare JMESPath expression.
> - **Using `element` outside the foreach entry.** It does not exist at the rule level.
> - **Putting `synchronize` inside the entry.** It belongs at the `generate` level next to `foreach`.
> - **Specifying both `data` and `clone` in one entry.** Only one is allowed.
> - **A missing annotation.** If the list expression has nothing to split, the rule has nothing to loop over, so give triggers the annotation the rule expects.
> - **Forgetting RBAC.** The background controller must be able to create the generated kind.

## Your mission: cloneList and generate foreach Lab

You can now clone several labelled source objects with `cloneList` and generate one resource per list element with `foreach`. The mission asks you to write one policy of each kind for a platform namespace setup and prove both by creating namespaces.

Pause the playground, start the lab, and submit your work as often as you like:

```sh
astrona stop ats-011-playground-0503
astrona run --git ssh://git@github.com/astrona-io/ATS011.git -c sections/section-050/module-03/labs/lab-01
astrona submit -c sections/section-050/module-03/labs/lab-01
```

When the lab passes, remove it and return to the playground:

```sh
astrona destroy ats-011-lab-053
astrona start ats-011-playground-0503
```

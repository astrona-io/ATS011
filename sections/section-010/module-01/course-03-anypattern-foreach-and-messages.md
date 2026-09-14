# Part 3: anyPattern, foreach & Failure Messages

## When one shape isn't enough: anyPattern

`pattern` demands one exact shape. But real policies are often more forgiving than that: "every Pod needs a `team` label, *or* it lives in a namespace that already carries an `owner` annotation." That's not one shape, it's a choice between shapes — and `anyPattern` is Kyverno's OR.

```yaml
validate:
  message: "Pods must carry a team label, or their namespace must be pre-approved."
  anyPattern:
    - metadata:
        labels:
          team: "?*"
    - metadata:
        annotations:
          approved-namespace: "true"
```

Kyverno tries each entry in `anyPattern` in order and the rule passes the moment **any one** of them matches. Only if every single entry fails does the rule fail.

The most useful way to build a mental model of that is to submit three Pods: one satisfying the first branch, one satisfying the second, and one satisfying neither. The third is the interesting one — pay attention to how many branches the error reports.

> [!TIP]
> **Try it — two ways to pass, one way to fail**
>
> ```sh
> kubectl run any-a --image=nginx --restart=Never --labels=team=platform
>
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata:
>   name: any-b
>   annotations:
>     approved-namespace: "true"
> spec:
>   containers: [{name: app, image: nginx}]
> EOF
>
> kubectl run any-c --image=nginx --restart=Never
> ```
>
> Expect something like:
>
> ```text
> pod/any-a created
> pod/any-b created
> Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
>
> resource Pod/default/any-c was blocked due to the following policies
>
> team-or-approved:
>   team-or-approved-ns: 'validation error: Pods must carry a team label, or be annotated as pre-approved. rule team-or-approved-ns[0] failed at path /metadata/labels/team/ rule team-or-approved-ns[1] failed at path /metadata/annotations/'
> ```
>
> Two different Pods, two different branches, both admitted — that is the OR. And
> when nothing matches, the error reports **every** branch, indexed:
> `[0]` names the path the label branch stopped at, `[1]` the annotation branch.

That indexing is worth noting, because it is what makes a failed `anyPattern` debuggable at all: the bracketed number is the branch's position in the list you wrote, and each one carries its own failure path. (Older Kyverno material sometimes says only the last branch is reported — on v1.19.1 that is not what happens, and the full list is considerably more useful.)

Contrast this with stacking multiple entries under `pattern` itself, which would be read as AND (every field must match) — `anyPattern` is the one and only place OR logic lives inside a `validate` block (deny-rule conditions have their own `any`/`all`, which is a different mechanism covered together with preconditions in Section 020).

## Validating every item of a list: foreach

Part 2 ended with a warning: a plain `pattern` against `spec.containers` only really validates a single-container Pod, because a list under `pattern` is matched by position — pattern index 0 checks container index 0, and nothing checks index 1 if the Pod has two containers.

`foreach` fixes this by giving you an explicit loop. You name a list to iterate with `list`, refer to the current item as `element`, and write a nested `pattern` (or `deny`) that runs once per item:

```yaml
validate:
  message: "Every container must set CPU and memory limits."
  foreach:
    - list: "request.object.spec.containers"
      pattern:
        resources:
          limits:
            memory: "?*"
            cpu: "?*"
```

`list` is a JMESPath expression (Section 070 covers JMESPath and variables in depth — for now, read `request.object.spec.containers` as simply "the containers array of the incoming resource"). Kyverno evaluates the nested `pattern` once for every element of that array, and the whole rule fails the first time any single element doesn't match. A three-container Pod where only the second container is missing a memory limit is rejected, and the error message identifies which index failed.

You can nest `foreach` too — for example, iterating a Pod's containers and, inside that, iterating each container's `volumeMounts` — for the rare policy that needs to reach two list levels deep. Most real policies need only one level.

## Writing a message that actually helps

Kyverno's default failure message is generic ("validation error: rule X failed"), so `validate.message` is not optional-in-practice — it is the single line a developer sees in their terminal when `kubectl apply` bounces. A good message names the *rule your organization has*, not the mechanism:

```yaml
# Weak — repeats the mechanism, tells the requester nothing new
message: "Pattern validation failed"

# Strong — names the actual rule and, ideally, the fix
message: >-
  Every container must declare resources.limits.cpu and
  resources.limits.memory. Add both under each container's
  `resources` block and try again.
```

Messages also accept variable substitution with `{{ }}` (full variable syntax lands in Section 070), which lets you echo back the offending value:

```yaml
message: >-
  Image "{{ request.object.spec.containers[0].image }}" is missing a
  digest or an approved tag.
```

Combine `foreach` with a message that references `{{ element.name }}` and a rejection tells the requester exactly *which* container it was, not just that "a" container somewhere failed — the difference between a policy developers curse at and one they trust.

Layer that `foreach` rule onto the policy you already have, then submit a Pod
whose *first* container is perfectly compliant and whose second is not. If
`foreach` is doing what it claims, the compliant first container must not save
the Pod.

> [!TIP]
> **Try it — the second container is checked too**
>
> ```sh
> kubectl apply -f - <<'EOF'
> apiVersion: v1
> kind: Pod
> metadata:
>   name: two-containers
>   labels:
>     team: platform
> spec:
>   containers:
>     - name: app
>       image: nginx
>       resources:
>         limits: { cpu: "250m", memory: "128Mi" }
>     - name: sidecar
>       image: busybox
>       command: ["sleep", "3600"]
> EOF
> ```
>
> Expect something like:
>
> ```text
> Error from server: error when creating "STDIN": admission webhook "validate.kyverno.svc-fail" denied the request:
>
> resource Pod/default/two-containers was blocked due to the following policies
>
> require-team-label:
>   check-container-limits: 'validation failure: validation error: Every container must set CPU and memory limits. rule check-container-limits failed at path /resources/limits/'
> ```
>
> The `team` label rule passed and the Pod was still rejected — the loop reached
> `sidecar`, which has no `resources` block at all. Note the failure path is
> `/resources/limits/`, relative to the *element*, not
> `/spec/containers/1/resources/limits/`: inside a `foreach`, paths are reported
> from the current item's root.

Give `sidecar` matching `limits` and re-apply, and the same Pod satisfies both
rules in one pass. That relative failure path is also the argument for putting
`{{ element.name }}` in the message: the path alone tells you *what* was wrong
but not *which* container it was.

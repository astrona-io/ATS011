# Section 010 Knowledge Check: Validation Rules

This section has four modules, and the questions below are grouped to match them. Test your diagnostic reasoning before attempting the lab. Try to answer each question yourself before expanding the explanation.

---

**1.** You apply a `ClusterPolicy` with a `validate` rule but no `match` block at all. What happens to an incoming Pod?

<details>
<summary>Show Answer</summary>

Nothing — the rule matches zero resources. A rule with no `match` block never selects anything, so Kyverno never evaluates it against the Pod. This is a deliberate safety default: there is no such thing as an accidental "match everything" rule.
</details>

---

**2.** A pattern requires `metadata.labels.env: "?*"`. A Pod is submitted with `labels: { env: "" }` (the key exists but its value is an empty string). Does it pass?

<details>
<summary>Show Answer</summary>

No. `?*` means "one or more characters" — the value must be non-empty. An empty string satisfies neither `?` (exactly one character) nor `*` alone as a non-empty requirement; the idiom `?*` specifically demands at least one character be present, and zero characters fails it.
</details>

---

**3.** Your policy has `spec.validationFailureAction: Audit`. A developer applies a Pod that fails the rule. What does the developer see in their terminal?

<details>
<summary>Show Answer</summary>

Nothing unusual — `kubectl apply` succeeds and the Pod is created. `Audit` mode never blocks the request; it only records a result entry in a `PolicyReport` (or `ClusterPolicyReport`) for someone to review later. If you need the developer to be stopped at admission time, the policy must use `Enforce`.
</details>

---

**4.** A `validate.pattern` targets `spec.containers` as a plain list, checking that `resources.limits.memory` is set. A Pod has two containers; only the second is missing the limit. Does the rule catch it?

<details>
<summary>Show Answer</summary>

Not reliably. A plain `pattern` against a list matches by position — pattern index 0 is checked against container index 0. If your pattern only defines one list entry, only the first container in the Pod is actually checked; the second container's fields are never inspected. `foreach` is the correct tool once a Pod (or any list field) can have more than one relevant element, because it evaluates the nested pattern independently against every item.
</details>

---

**5.** You write an `anyPattern` with three entries. The resource fails to match the first two but matches the third. What is the final result, and what does the returned error message contain if it had failed all three?

<details>
<summary>Show Answer</summary>

The rule passes — `anyPattern` succeeds the moment any single entry matches; the first two failing is irrelevant once the third succeeds. If instead all three entries had failed, Kyverno returns a validation error, but it only quotes the mismatch from the *last* entry evaluated — so when debugging a fully-failed `anyPattern`, you must inspect every branch yourself rather than trust the single quoted path in the error.
</details>

---

**6.** True or false: `validate.message` is required for a `validate` rule to function.

<details>
<summary>Show Answer</summary>

False, technically — Kyverno will fall back to a generic message if you omit it. But in practice it is not optional: without a specific `message`, the developer whose `kubectl apply` was rejected has no idea what your organization's actual rule is, only that "validation failed." A well-written `message` is part of the rule working correctly, not decoration.
</details>

---

**7.** A rule matches `kinds: [Pod]` with no `exclude` block, and `validationFailureAction: Enforce`. After you apply it, existing Pods created before the policy existed are still running and none of them comply. Why weren't they deleted or blocked retroactively?

<details>
<summary>Show Answer</summary>

Admission control — which is what `Enforce`/`Audit` govern — only fires on new admission requests: creates, updates, and (depending on rule config) certain other verbs. It cannot reach back in time and act on resources that already exist and are not being modified. Detecting and reporting on already-existing non-compliant resources is the job of **background scanning** (`spec.background: true`), covered in Section 030 — and even then, a background scan only reports; it does not delete or block anything on its own.
</details>

---

## Module 2 — Deny Rules and the Condition Vocabulary

**M2.1** A requirement reads "a Deployment may have at most 3 replicas". Write the condition a `validate.deny` rule needs, and explain what makes this the wrong job for `validate.pattern`.

<details>
<summary>Show Answer</summary>

`key: "{{ request.object.spec.replicas }}"`, `operator: GreaterThan`, `value: 3` — note the **negation**. A pattern describes the shape of an acceptable resource; "at most 3" is a numeric comparison, not a shape, and a pattern has no vocabulary for it beyond simple wildcards. The polarity is the thing to get right: `deny` conditions describe the *unacceptable* state, so the requirement "at most 3" becomes the condition "greater than 3".
</details>

---

**M2.2** With deny polarity, which is stricter — `conditions.any` or `conditions.all`?

<details>
<summary>Show Answer</summary>

`any` is stricter. Because a true condition *rejects*, `any` rejects as soon as a single condition holds, while `all` requires every condition to hold before anything is rejected. This reads backwards from the intuition built on `match.any`, and getting it wrong produces a rule that silently under-enforces: an `all` block written where `any` was meant still rejects something, just far less than intended.
</details>

---

**M2.3** Why does `message` matter more on a deny rule than on a pattern rule?

<details>
<summary>Show Answer</summary>

Because a deny failure carries no field path. A pattern failure reports `failed at path /metadata/labels/team/`, which tells the developer where to look; a deny failure reports only that the condition was true. The message is therefore the requester's entire diagnostic, which is why quoting the offending value back — `this one asks for {{ request.object.spec.replicas }}` — is worth the extra line.
</details>

---

**M2.4** Name the four set operators and say when the difference between `AnyIn` and `AllIn` actually matters.

<details>
<summary>Show Answer</summary>

`AnyIn`, `AllIn`, `AnyNotIn`, `AllNotIn` — a two-by-two grid of Any/All against In/NotIn. The Any/All axis only matters when `key` resolves to a **list**; against a single value the two are equivalent, which is why plenty of working policies use them interchangeably without their authors noticing — right up until a key starts resolving to more than one item and the rule quietly changes meaning.
</details>

---

**M2.5** A condition reads `key: "{{ request.object.metadata.labels.tier }}"` with `operator: AnyNotIn`. A Pod arrives with no labels at all. What happens, and what is the fix?

<details>
<summary>Show Answer</summary>

The variable does not resolve, which is an evaluation error rather than a condition that comes out false. The fix is the `|| ''` fallback: `{{ request.object.metadata.labels.tier || '' }}`. An empty string is legitimately not in the allowed list, so "absent" is then treated as "invalid" — which is almost always what a controlled-vocabulary rule wants.
</details>

---

**M2.6** Inside a `foreach ... deny`, why does the rule-level `message` often name every element rather than the offending one?

<details>
<summary>Show Answer</summary>

Because the rule-level message is evaluated against the whole resource, not against the current element. A message referencing `{{ request.object.spec.containers[*].image }}` resolves to the full list regardless of which element failed. To name only the offender, reference `{{ element.image }}` in the message instead.
</details>

---

## Module 3 — Validation Anchors

**M3.1** A pattern contains `(image): "*:latest"` alongside `imagePullPolicy: Always`. A container runs `nginx:1.27` with `imagePullPolicy: IfNotPresent`. Is it admitted?

<details>
<summary>Show Answer</summary>

Yes. The conditional anchor did not match — the image is not a `:latest` reference — so its sibling fields were never examined. A container running `nginx:latest` with that same `IfNotPresent` would be rejected. The anchor is the "if"; the siblings are the "then".
</details>

---

**M3.2** What is the difference between `()` and `=()`?

<details>
<summary>Show Answer</summary>

`()` asks *does this field have this value?* — the siblings are enforced only when the anchored value matches. `=()` asks *does this field exist at all?* — the pattern nested under it is enforced whenever the key is present, whatever its value. `=()` is what makes it safe to reach into an optional block: a plain `volumes:` key in a pattern would require every Pod to declare volumes, rejecting perfectly ordinary Pods for the wrong reason.
</details>

---

**M3.3** A Pod has two containers; only the second defines a `readinessProbe`. Under `^(containers): [- readinessProbe: {...}]`, is it admitted? What about under an equivalent `foreach`?

<details>
<summary>Show Answer</summary>

Admitted under `^()` — the existence anchor requires that **at least one** element matches, and one does. Rejected under a `foreach`, which evaluates its body against every element and fails on the first that does not comply. And a plain positional list pattern would check only index 0 and reject it for a third, different reason. Three constructs, three different meanings on the same resource.
</details>

---

**M3.4** Does `X(hostPath): "/tmp"` forbid only `hostPath` volumes pointing at `/tmp`?

<details>
<summary>Show Answer</summary>

No. `X()` checks **presence only** and ignores the value entirely — that pattern forbids `hostPath` outright, exactly as `X(hostPath): "null"` would. The value is a placeholder the schema requires. To allow `hostPath` but restrict where it points, use `=(hostPath)` with a negated value such as `path: "!/var/lib"`.
</details>

---

**M3.5** Why can't a conditional anchor `()` express "Pods using corp.reg.com images must set imagePullSecrets"?

<details>
<summary>Show Answer</summary>

Because `()` governs only its own **siblings** — fields in the same element of the pattern. The condition here is about a container's image, and the requirement is about `spec.imagePullSecrets`, which is in a different branch of the resource entirely. The global anchor `<()` is the one that reaches across: when its condition is false the whole rule is skipped, and when true every other part of the pattern applies, wherever it sits.
</details>

---

**M3.6** A dashboard shows a rule with a large `skip` count and no `fail` results. Is the cluster compliant with that rule?

<details>
<summary>Show Answer</summary>

Unknown — and that is the point. A skipped rule is not a passing one. When an anchor does not apply, the check is skipped rather than passed, and reports record `skip` distinct from `pass`. A large `skip` count means most resources were never assessed, which is a very different situation from most of them complying, and reading a green dashboard as compliance gets it wrong.
</details>

---

## Module 4 — The podSecurity Subrule

**M4.1** Name the three Pod Security Standard levels and say what changes between the second and the third.

<details>
<summary>Show Answer</summary>

`privileged`, `baseline`, `restricted`, and they are cumulative. `baseline` **forbids** known privilege-escalation paths — privileged containers, host namespaces, host ports, dangerous capabilities — and an ordinary application generally passes it unchanged. `restricted` additionally **requires** positive hardening: `runAsNonRoot`, `allowPrivilegeEscalation: false`, dropping all capabilities, and a seccomp profile. That shift from forbidding to requiring is why most off-the-shelf images fail `restricted` until their manifests are adjusted.
</details>

---

**M4.2** How does a PSS violation message differ in structure from an ordinary pattern failure?

<details>
<summary>Show Answer</summary>

There is no single `failed at path`. Instead there is one parenthesised block per violated control — `(Forbidden reason: <control>, field error list: [<field>: <problem>])` — and a Pod violating several controls produces several blocks in one message. Fixing only the first and resubmitting just surfaces the next, so read the whole message.
</details>

---

**M4.3** One workload needs a capability that `restricted` forbids. Why is dropping that namespace to `baseline` the wrong fix?

<details>
<summary>Show Answer</summary>

Because it trades one exemption for roughly a dozen. `restricted` is a set of controls, and dropping to `baseline` abandons the seccomp requirement, the non-root requirement, the privilege-escalation requirement, and the capability drop — when the actual need was one of them. `podSecurity.exclude` with a `controlName` relaxes the single control and leaves the rest of the profile enforced, and it leaves the exemption documented next to the policy rather than invisible in a namespace's configuration.
</details>

---

**M4.4** How would you permit exactly `NET_BIND_SERVICE` while still forbidding every other added capability?

<details>
<summary>Show Answer</summary>

Scope the exclusion with `restrictedField` and `values`:

```yaml
exclude:
  - controlName: "Capabilities"
    restrictedField: "spec.containers[*].securityContext.capabilities.add"
    values: ["NET_BIND_SERVICE"]
```

`restrictedField` names the exact field the control governs and `values` lists what is permitted in it, so a container adding `SYS_ADMIN` is still rejected by the same rule. Omitting `restrictedField` selects all restricted fields for the control, which is the broader form.
</details>

---

**M4.5** Why pin `version` on an enforcing `podSecurity` rule instead of leaving it at `latest`?

<details>
<summary>Show Answer</summary>

Because the Pod Security Standards are revised between Kubernetes releases. With `latest`, a Kyverno upgrade can add controls to a profile and start rejecting workloads that passed yesterday — with no change to your policy or anyone's manifests, surfacing as deployments failing for a reason nobody changed. Pinning makes a profile change an explicit decision. For an `Audit` policy `latest` is arguably better, since there you *want* to see new violations.
</details>

---

**M4.6** How does Kyverno's `podSecurity` rule differ from Kubernetes' built-in Pod Security Admission?

<details>
<summary>Show Answer</summary>

PSA is configured by a namespace label and applies one level to the whole namespace with no per-control exemptions — exempting anything requires a cluster-level change to the API server's admission configuration. Kyverno's rule is configured by a policy, can use any `match`/`exclude` selector, can exclude individual controls scoped by image or by field value, and reports into `PolicyReport` objects alongside every other policy. They are independent admission paths, so many clusters run both: PSA as a floor, Kyverno on top for granularity and reporting.
</details>


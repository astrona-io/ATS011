# Summary

Autogen rewrites a rule written for Pods so that it also applies to the controllers that create Pods, such as Deployments, StatefulSets, DaemonSets, Jobs and CronJobs. It copies the rule and rewrites the field paths for each template, for example from `spec` to `spec.template.spec` and, for a CronJob, `spec.jobTemplate.spec.template.spec`. The generated rules are visible under `status.autogen` when you read the applied policy.

The annotation `pod-policies.kyverno.io/autogen-controllers` limits autogen to chosen controllers or turns it off. Autogen does nothing when a rule's `match` or `exclude` names a kind other than `Pod`, and no error tells you. It also rewrites a pattern that already expects a controller shape into a path that no resource has. Both cases produce a policy that protects less than it seems to. Write each rule for a Pod, one kind per rule, and check `status.autogen`.

Key facts:

- Autogen needs a rule whose kinds are only `Pod`.
- Read the generated rules in `status.autogen`.
- The `autogen-controllers` annotation scopes or disables autogen.

<!-- astrona:playground:destroy -->

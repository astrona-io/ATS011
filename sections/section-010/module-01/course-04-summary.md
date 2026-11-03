# Summary

A `validate` rule describes the shape a resource must have. The `pattern` block is written like the resource itself, and Kyverno compares it field by field with the incoming object. The wildcard `?` stands for one character and `*` for any number of characters, so `?*` means a non-empty value. Operators such as `>=` and `!-` compare values inside the pattern.

The failure action controls the effect of a mismatch. With `Enforce` the API server rejects the object and returns the policy message. With `Audit` the object is admitted and the failure appears in a policy report. A rule with no `match` block selects nothing.

`anyPattern` accepts a resource that matches any one of several shapes. A plain pattern against a list compares by position, so it does not check every container. `foreach` loops over a list, names the current item `element`, and applies a nested pattern or deny block to each item independently. The first item that fails makes the whole rule fail, and a message that includes `element.name` tells the user which container is wrong.

Key facts:

- `?*` requires at least one character.
- `Audit` writes policy report entries and never blocks.
- Use `foreach` when every list element must comply.

<!-- astrona:playground:destroy -->

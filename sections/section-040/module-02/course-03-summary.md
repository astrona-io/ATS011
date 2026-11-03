# Summary

A `mutate.foreach` rule loops over a list and patches each element independently. Inside the loop, `element` is the current item, so the new value can be computed from the old one. The `(name)` anchor is enough when the patch does not depend on the existing value. `foreach` is needed when it does.

A mutate rule runs again on every UPDATE. A change that derives a new value from an old one compounds each time, for example when a prefix is added to an image on every update, and no error reports it. The fix is a guard. A `preconditions` block inside the `foreach` entry applies the change only when it has not been made yet, and `operations: [CREATE]` removes the update path where that is acceptable.

When two mutate rules write the same field, the order of rules of one type is not defined. Restructure the rules so that they write different fields or so that one result does not depend on the other.

Key facts:

- Mutate rules run again on UPDATE.
- A precondition inside `foreach` makes the patch idempotent.
- Two rules on one field have no defined order.

<!-- astrona:playground:destroy -->

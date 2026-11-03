# Summary

A plain pattern cannot say "if this field has this value, then that field is required". Anchors add the missing conditions. The conditional anchor `()` applies the sibling fields of an element only when the anchored field matches. The equality anchor `=()` checks inside an optional block without requiring that the block exists.

The existence anchor `^()` works on lists and requires that at least one element matches, which is the shape that neither a positional pattern nor `foreach` gives. The negation anchor `X()` requires that a key is absent and ignores its value. The global anchor `<()` skips the whole rule when its condition is false, so the condition and the requirement can sit in different branches of the resource.

When an anchor condition is not met, the rule skips; it does not fail. A rule whose anchors never match never ran. The failure path in a message shows which part of the pattern failed. To choose between anchors and a deny rule, ask whether the requirement is about the shape of the resource or about comparing values.

Key facts:

- Anchors skip when their condition is false.
- `^()` needs one matching element, not all of them.
- `X()` forbids a key whatever its value.

<!-- astrona:playground:destroy -->

# Summary

The `validate.assert` rule checks a resource with an assertion tree. The tree starts at `object` and moves down through the fields of the resource. A key in parentheses is a JMESPath expression. Kyverno evaluates it against the current node, and every comparison happens in a leaf of the tree.

The `~.` modifier checks each item of a list or map, and `->name` stores a value so that children can read it as `$name`. Kyverno does not promise an order between sibling keys, so checks must not depend on each other except through bindings. A list written without `~.` must match the resource exactly, item by item. Compared with `pattern`, an assertion tree can calculate, which makes it the better choice for lengths, sums and string functions.

The `validate.manifests` rule checks that a manifest was signed by trusted attestors. `count` sets how many signers must agree, `ignoreFields` lists fields that may change after signing, and `dryRun` lets Kyverno compare against what the API server would store. It protects the origin of a manifest, while the other validate subrules protect its content.

Key facts:

- `validate.assert` starts in Kyverno 1.13.
- A projection selects data, and the result becomes the current node.
- `~.` iterates, and `->name` binds.
- Keep `ignoreFields` as short as possible.

<!-- astrona:playground:destroy -->

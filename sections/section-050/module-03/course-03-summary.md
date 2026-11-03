# Summary

A plain clone rule copies one named object. The setting `generate.cloneList` copies many: it names a source namespace, a list of kinds written as `group/version/Kind`, and an optional label selector. The destination is the ordinary `generate.namespace`, so the two namespace fields mean different things. With a selector, only labelled source objects spread, which makes the label an opt-in. Without one, every object of the listed kinds is copied.

When the number of resources depends on the trigger, `generate.foreach` loops over a list. The `list` is a bare JMESPath expression. Inside the loop `element` and `elementIndex` identify the current item, `context` can give it a friendly name, and `preconditions` skip elements. Each entry supplies its own `apiVersion`, `kind`, `name`, `namespace` and either `data` or `clone`, evaluated per element. Settings such as `synchronize` stay at the generate level.

In both forms the background controller needs permission for every kind it creates.

Key facts:

- `cloneList` needs a source namespace and `kinds`; the selector is optional but decides what is shared.
- `element` and `elementIndex` exist only inside a foreach entry.
- A failed precondition skips one element, not the whole rule.

<!-- astrona:playground:destroy -->

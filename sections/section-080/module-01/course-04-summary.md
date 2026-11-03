# Summary

A `patchesJson6902` rule applies RFC 6902 operations (`add`, `remove` and `replace`) to a resource. Each operation has a JSON Pointer `path`. An array element is addressed by its index, and `/-` appends. A literal `/` in a key, such as an annotation name, must be written `~1`, and a literal `~` is written `~0`. If the pointer is wrong, the operation silently addresses a structure that does not exist.

The operations are applied as one atomic list, so a failure anywhere stops the whole patch. A missing target can be a silent no-op or a rejected request depending on the operation. A `preconditions` check that the target exists makes the rule behave the same way in both cases. Use `patchStrategicMerge` for most changes and JSON Patch when you must remove a field or address a precise position.

Key facts:

- Escape `/` as `~1` in pointers.
- `add` is safe; guard `remove` and `replace`.
- The patch list is atomic.

<!-- astrona:playground:destroy -->

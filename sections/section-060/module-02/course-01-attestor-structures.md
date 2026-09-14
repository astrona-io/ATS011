# Part 1: Attestor Structures and Trust Material

## `attestors` is a list, and the list means AND

Module 1's rule carried a single attestor block holding a single key, which makes the structure look simpler than it is. The real shape is two levels deep, and each level composes differently:

```text
attestors:                    <- every block must be satisfied   (AND)
  - count: 1
    entries:                  <- `count` of these must match     (M-of-N)
      - keys: ...
      - keys: ...
  - count: 1                  <- a second, independent requirement
    entries:
      - keys: ...
```

Read it as: *"satisfy every block; satisfy a block by matching at least `count` of its entries."* That is what lets one rule express "signed by CI **and** countersigned by the security team" — two blocks, one key each.

The cheapest way to confirm the outer AND is to give a rule two blocks where the image genuinely satisfies only the first, and read which index the error names.

> [!TIP]
> **Try it — the second block is evaluated, and named**
>
> ```sh
> kubectl apply -f two-attestor-blocks.yaml
> kubectl run both-b --image=ghcr.io/kyverno/test-verify-image:signed --restart=Never
> ```
>
> Expect something like:
>
> ```text
> Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
>
> resource Pod/default/both-b was blocked due to the following policies
>
> two-attestor-blocks:
>   needs-both: |-
>     failed to verify image ghcr.io/kyverno/test-verify-image:signed: .attestors[1].entries[0].keys: no matching signatures: invalid signature when validating ASN.1 encoded signature
> ```
>
> The image *is* correctly signed by the key in block `[0]` — and it is rejected
> anyway, because block `[1]` holds a different key that never signed it. The
> error path `.attestors[1].entries[0].keys` tells you exactly which block and
> which entry failed, which is the fastest way to debug a multi-attestor rule.

## `count` turns entries into M-of-N

Inside one block, `count` says how many of the listed entries must match. It is not a validation of the list's length — it is a threshold.

Give a block two entries where only one key really signed the image, and vary `count`:

| `count` | Entries listed | Entries that can match | Result |
| :--- | :--- | :--- | :--- |
| `1` | 2 | 1 | **admitted** |
| `2` | 2 | 1 | **denied** |

Verified on v1.19.1 against the same image and the same two keys — only the `count` value changed. `count: 1` across two entries is an **OR**: either signer will do. `count: 2` across the same two is an **AND**, expressed inside a single block.

That gives you two ways to write "both of these keys" — two blocks of one entry each, or one block of two entries with `count: 2` — and they differ in how failures are reported. Separate blocks fail with a specific `.attestors[N]` index, which is easier to diagnose; a single block with a high `count` reports the block as a whole. For a policy other people will debug, prefer separate blocks.

> [!NOTE]
> Omitting `count` requires **all** entries in the block to match. That default is easy to misread in the other direction: a block listing three trusted keys with no `count` is not "any of our three signers", it is "all three must have signed". If you meant any-of, you must write `count: 1` explicitly.

## Three kinds of trust material

An `entries` item carries exactly one kind of trust material. The schema offers three, plus a few modifiers:

| Entry field | What it matches on |
| :--- | :--- |
| `keys` | a literal public key (or a reference to one), as in Module 1 |
| `certificates` | an X.509 certificate and/or certificate chain |
| `keyless` | an *identity* — who signed, and which OIDC provider vouched for them |
| `attestor` | a reference to another attestor definition, for reuse |

`keys` is the shape Module 1 used and the easiest to reason about: a long-lived key pair, the public half pasted into the policy. Its weakness is also its simplicity — a long-lived private key is a long-lived thing to lose.

**Keyless** signing removes the key entirely. Instead of holding a secret, a signer authenticates to an OIDC provider, receives a short-lived certificate from Sigstore's CA (Fulcio) binding that identity to a freshly-generated key, signs, and publishes the signature and certificate to the transparency log (Rekor). The private key is discarded within minutes. Verification then checks the *identity in the certificate* rather than a key you hold:

```yaml
attestors:
  - count: 1
    entries:
      - keyless:
          subject: "https://github.com/my-org/my-repo/.github/workflows/build.yaml@refs/heads/main"
          issuer: "https://token.actions.githubusercontent.com"
          rekor:
            url: https://rekor.sigstore.dev
```

`subject` is the identity that signed — for GitHub Actions, the workflow file and ref. `issuer` is the OIDC provider that asserted it. Together they say "signed by *this workflow* in *this repository*, as vouched for by GitHub" — a far more specific claim than "signed by whoever holds this key", and one that cannot be satisfied by an attacker who stole a key, because there is no key to steal.

> [!NOTE]
> The playground cannot demonstrate keyless verification. It needs a publicly-reachable image signed keyless by an identity stable enough to write into a policy, and the demo images this section uses are key-signed. The mechanism above is drawn from the rule schema and the Sigstore model rather than from a transcript — treat the key-based checkpoints as the verified ones, and keyless as the shape to recognise. If you want to see it end to end, `cosign sign` against an image in a registry you control, using an OIDC identity you can authenticate as, is the exercise.

`certificates` sits between the two: you supply a certificate or root, and verification checks the signature chains to it. It suits organisations with existing PKI that want signing tied to it rather than to Sigstore's public infrastructure.

> [!WARNING]
> **Common pitfalls**
>
> - **Reading multiple `entries` as "any of these".** Without `count`, all of them must match. Write `count: 1` if you meant any-of.
> - **Reading multiple `attestors` blocks as alternatives.** They are ANDed; every block must be satisfied.
> - **Putting two kinds of trust material in one entry.** An entry carries one of `keys`, `certificates`, or `keyless`.
> - **Pinning a keyless `subject` to a mutable ref.** `@refs/heads/main` verifies that *the workflow on main* signed it; anyone who can change that workflow can change what passes.

## Section recap

`attestors` composes at two levels: blocks are ANDed, and within a block `count` sets how many entries must match — defaulting to all of them, which is the opposite of what a list of trusted keys usually intends. An entry carries a public key, a certificate, or a keyless identity, where keyless verifies *who signed* via a short-lived Fulcio certificate rather than a key you hold and must protect.

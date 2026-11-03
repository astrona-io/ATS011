# ATS011 - KCA: Writing Policies

[![Liberapay](https://img.shields.io/badge/Liberapay-Support_Astrona.io-F6C915?logo=liberapay&logoColor=black&style=for-the-badge)](https://liberapay.com/Astrona.io)

Welcome to **ATS011**, a comprehensive, free training curriculum designed to help you fully master and pass the **Writing Policies** domain of the **Kyverno Certified Associate (KCA)** exam.

Writing Policies represents **32% of the total KCA exam weight** — the single heaviest domain on the exam. This repository bridges the conceptual model of admission control with real-world, hands-on policy authoring, transforming you from someone who can read a `ClusterPolicy` into someone who can write, debug, and reason about one under exam pressure.

---

## Before You Start: Container Runtime Requirements

Every lab in this course boots a **`kind` Kubernetes cluster running Kyverno's four controllers** (admission, background, cleanup, reports). That is substantially heavier than a single-container lab.

> [!IMPORTANT]
> **Give your container runtime VM at least 6–8 GB of RAM.** On Docker Desktop or Podman on macOS/Windows, the container engine runs inside a virtual machine with its own memory budget, and the default allocation (often 2 GB) is **not enough**. With too little memory the cluster appears to start, then the Kubernetes API server begins returning `connection reset by peer` or `TLS handshake timeout` partway through a lab, and Kyverno's pods restart in a loop.
>
> **Podman:**
> ```bash
> podman machine stop
> podman machine set --memory 8192 --cpus 4
> podman machine start
> podman machine list          # confirm the new MEMORY value
> ```
>
> **Docker Desktop:** Settings → Resources → Memory → set to 8 GB → Apply & Restart.
>
> Also make sure you are **plugged into mains power** for longer lab sessions — a laptop that sleeps mid-lab will leave the cluster in a broken state and you will have to `astrona destroy` and start over.

Other prerequisites:

* `astrona` CLI (`astrona run` / `submit` / `destroy`)
* `kubectl`
* `kind`
* A running container engine (Docker or Podman)

---

## Complete Curriculum & Lab Mapping

The training series is divided into **11 main sections** mapping one-to-one onto the KCA's Writing Policies competencies, plus a **Section 000 primer** for the policy-object topics that belong to no single competency.

Sections are deliberately *not* all the same size. Validation Rules is the heaviest competency on the exam and carries five modules; Autogen and Cleanup carry one each. Every section has a scenario quiz, a graded practice lab, and a **Section Capstone Challenge**; every module additionally has an ungraded **playground** — a throwaway cluster with Kyverno running and no policies on it — linked from the top of its reader:

| Section & Domain | Module & Chapter Reader | Practice Lab | astrona CLI Run Command |
| :--- | :--- | :--- | :--- |
| **000: Policy Objects and Rule Anatomy (Primer)** | [M1: Policy Objects and Rule Anatomy](sections/section-000/module-01/course.md) | [lab](sections/section-000/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-000/module-01/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-000/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-000/capstone/labs/lab-01` |
| **010: Validation Rules** | [M1: Pattern-Based Validation](sections/section-010/module-01/course.md) | [lab](sections/section-010/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-01/labs/lab-01` |
|  | [M2: Deny Rules and the Condition Vocabulary](sections/section-010/module-02/course.md) | [lab](sections/section-010/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-02/labs/lab-01` |
|  | [M3: Validation Anchors](sections/section-010/module-03/course.md) | [lab](sections/section-010/module-03/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-03/labs/lab-01` |
|  | [M4: The podSecurity Subrule](sections/section-010/module-04/course.md) | [lab](sections/section-010/module-04/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-04/labs/lab-01` |
|  | [M5: Assertion Trees and Manifest Verification](sections/section-010/module-05/course.md) | [lab](sections/section-010/module-05/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-05/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-010/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/capstone/labs/lab-01` |
| **020: Preconditions** | [M1: Preconditions](sections/section-020/module-01/course.md) | [lab](sections/section-020/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/module-01/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-020/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-020/capstone/labs/lab-01` |
| **030: Background Scans** | [M1: Background Scanning](sections/section-030/module-01/course.md) | [lab](sections/section-030/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/module-01/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-030/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-030/capstone/labs/lab-01` |
| **040: Mutation Rules** | [M1: Mutation Rules](sections/section-040/module-01/course.md) | [lab](sections/section-040/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-01/labs/lab-01` |
|  | [M2: Per-Element Mutation and Idempotency](sections/section-040/module-02/course.md) | [lab](sections/section-040/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-02/labs/lab-01` |
|  | [M3: Mutation Anchors](sections/section-040/module-03/course.md) | [lab](sections/section-040/module-03/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/module-03/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-040/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-040/capstone/labs/lab-01` |
| **050: Generation Rules** | [M1: Generation Rules](sections/section-050/module-01/course.md) | [lab](sections/section-050/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-01/labs/lab-01` |
|  | [M2: Generating for What Already Exists](sections/section-050/module-02/course.md) | [lab](sections/section-050/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-02/labs/lab-01` |
|  | [M3: Cloning Several Resources and generate foreach](sections/section-050/module-03/course.md) | [lab](sections/section-050/module-03/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/module-03/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-050/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-050/capstone/labs/lab-01` |
| **060: VerifyImage Rules** | [M1: Image Signature & Attestation Verification](sections/section-060/module-01/course.md) | [lab](sections/section-060/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-01/labs/lab-01` |
|  | [M2: Attestors, Digests, and Registry Access](sections/section-060/module-02/course.md) | [lab](sections/section-060/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-02/labs/lab-01` |
|  | [M3: The images Variable and Image Extraction](sections/section-060/module-03/course.md) | [lab](sections/section-060/module-03/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/module-03/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-060/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-060/capstone/labs/lab-01` |
| **070: Variables & API Calls in Policies** | [M1: Variables & API Calls in Policies](sections/section-070/module-01/course.md) | [lab](sections/section-070/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-01/labs/lab-01` |
|  | [M2: Context Beyond apiCall](sections/section-070/module-02/course.md) | [lab](sections/section-070/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-02/labs/lab-01` |
|  | [M3: The Kyverno JMESPath Function Library](sections/section-070/module-03/course.md) | [lab](sections/section-070/module-03/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/module-03/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-070/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-070/capstone/labs/lab-01` |
| **080: JSON Patches** | [M1: JSON Patches](sections/section-080/module-01/course.md) | [lab](sections/section-080/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-080/module-01/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-080/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-080/capstone/labs/lab-01` |
| **090: Autogen Rules** | [M1: Autogen Rules](sections/section-090/module-01/course.md) | [lab](sections/section-090/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-090/module-01/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-090/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-090/capstone/labs/lab-01` |
| **100: Cleanup Policies** | [M1: Cleanup Policies](sections/section-100/module-01/course.md) | [lab](sections/section-100/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-100/module-01/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-100/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-100/capstone/labs/lab-01` |
| **110: Common Expression Language (CEL)** | [M1: CEL in Kyverno Policies](sections/section-110/module-01/course.md) | [lab](sections/section-110/module-01/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-110/module-01/labs/lab-01` |
|  | [M2: The CEL-Native Policy Family](sections/section-110/module-02/course.md) | [lab](sections/section-110/module-02/labs/lab-01) | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-110/module-02/labs/lab-01` |
| | **Section Capstone Challenge** | **[capstone](sections/section-110/capstone/labs/lab-01)** | `astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-110/capstone/labs/lab-01` |

Every module has a playground, a summary page and a graded lab, and every section (the primer included) has a capstone lab: 25 module labs and 12 capstones in total. Every lab and playground added by the gap-closing build is **UNTESTED** against a live cluster until someone runs it; `astrona validate -c <dir>` checks their configs statically. Section quizzes and the final domain quiz are graded `quiz.yaml` question banks with a pass score of 70.

---

## How to Navigate This Course

To get the most value out of this curriculum, follow this step-by-step roadmap:

0.  **Start with the primer, if Kyverno is new to you:** `sections/section-000/` covers the policy object itself — scoping, failure actions, rule ordering — which every later section assumes. Skip it if you already write policies daily.
1.  **Enter a Domain Portal:** Navigate into a section directory, such as `sections/section-010/`, and open its `README.md` to review the section's core philosophy and the competencies it targets.
2.  **Read the Chapters:** Open and read each module in order — `module-NN/course.md` is a short landing page, and the numbered `course-0N-*.md` parts beside it carry the material. Sections are not all the same size: Validation Rules has five modules, several have two or three, the rest have one. Focus on the verified command transcripts and the `[!NOTE]` callouts, which document real Kyverno behaviour discovered by running the policies, including several gotchas that contradict what the docs imply.
3.  **Run the Playground Alongside the Reading:** Every module links an ungraded playground at the top of its reader — a throwaway cluster with Kyverno running and no policies on it. The `> [!TIP] Try it` checkpoints in the chapters are written to run there. Nothing is submitted and nothing is scored.
4.  **Test Your Diagnostics:** Open `quiz.yaml` inside that section and answer its scenario questions. Expand the collapsible `<details>` blocks to read the explanations. Since the KCA is itself a multiple-choice exam, these are your closest rehearsal.
5.  **Practice the Sandbox:** Run the section's module lab to build muscle memory writing the policy type from scratch, and grade yourself with `astrona submit`.
6.  **Conquer the Capstone Challenge:** Boot the section's **Capstone Challenge Lab**, which combines the section's techniques into a single harder policy, and run the automated validation suite to confirm a passing state.
7.  **Simulate the Exam:** Once you have worked through the eleven competency sections, open **`sections/final-domain-quiz.yaml`** and complete the final closed-book domain exam simulator under time pressure to audit your readiness.

---

## Working a Lab

Each lab follows the same loop:

```bash
# 1. Launch the environment (creates a kind cluster and installs Kyverno)
astrona run --git git@github.com:astrona-io/ATS011.git -c sections/section-010/module-01/labs/lab-01

# 2. Read the task
#    sections/section-010/module-01/labs/lab-01/question.md

# 3. Write and apply your policy against the cluster
kubectl apply -f my-policy.yaml

# 4. Grade yourself — re-submit as often as you like
astrona submit -c sections/section-010/module-01/labs/lab-01

# 5. Tear down when finished (the lab name is the config's metadata.name)
astrona destroy ats-011-lab-011
```

A `PROCTOR: PASS` verdict means the grading script confirmed your policy actually enforces the required behaviour against live admission requests. Stuck? Each lab ships a full `solution.md` walkthrough.

---

## Kyverno Version

All labs install and are verified against **Kyverno v1.19.1**, using server-side apply:

```bash
kubectl apply --server-side -f https://github.com/kyverno/kyverno/releases/download/v1.19.1/install.yaml
```

> [!NOTE]
> Server-side apply is required — a plain `kubectl apply` of this manifest fails with `metadata.annotations: Too long: may not be more than 262144 bytes` on the Kyverno CRDs. The labs' bootstrap scripts already handle this for you; the note matters if you install Kyverno yourself while experimenting.
>
> You will also see `Warning: kyverno.io/v1 ClusterPolicy is deprecated...` on every `ClusterPolicy` apply. That is expected on this version and safe to ignore — `ClusterPolicy` remains the KCA exam's subject matter. Section 110 covers the newer CEL-based policy types that warning points toward.

---

## KCA Exam Context

The Kyverno Certified Associate exam is a **90-minute, online proctored, multiple-choice exam** — not a performance-based one. That is worth knowing before you plan your study: the labs in this repository exist to build a working mental model of *why* Kyverno behaves as it does, and the section quizzes plus **`sections/final-domain-quiz.yaml`** are what rehearse the format you will actually sit. Do the labs to understand; do the quizzes to prepare.

The exam covers six domains:

| Domain | Weight |
| :--- | :--- |
| **Writing Policies** | **32%** ← *this repository* |
| Fundamentals of Kyverno | 18% |
| Installation, Configuration, and Upgrades | 18% |
| Kyverno CLI | 12% |
| Applying Policies | 10% |
| Policy Management | 10% |

This curriculum covers the Writing Policies domain exclusively and in depth. Every listed competency of that domain — validation rules, preconditions, background scans, mutation rules, generation rules, verifyImage rules, variables and API calls, JSON patches, autogen rules, cleanup policies, and CEL — maps to its own section here.

---

## Support This Project

ATS011 is free KCA training material. If it helped you on your policy-authoring journey, consider supporting ongoing work and resource development via [Liberapay](https://liberapay.com/Astrona.io).

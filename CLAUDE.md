# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS011 only)

Everything above is general. This section is only true for this repository.

### What the student is trying to learn

- **The goal:** pass the **Writing Policies** domain of the **Kyverno Certified Associate (KCA)** exam. It is 32% of the exam, the heaviest domain.
- **What the exam tests:** the KCA is a 90-minute, online proctored, multiple-choice exam. The labs build the skill behind the questions: every policy is proved with a real admission decision (an object accepted before is now rejected, or the reverse).
- **The versions:** Kyverno v1.19.1 (installed with `kubectl apply --server-side`). `ClusterPolicy` (`kyverno.io/v1`) prints a deprecation warning on this version; that is expected. The CEL-native family is `policies.kyverno.io/v1`.
- **Out of scope:** the Kyverno CLI belongs to a different exam domain and is not taught here.
- **Examples:** plain Kubernetes names (Pod, Deployment, ConfigMap, namespaces such as `staging`). There is no space theme in this course.

### Lab and playground rules

- Every module has a playground and a graded module lab. Every section (000 included) has a capstone lab.
- Lab names: module N of section SSS0 is `ats-011-lab-SSN` (section 010 module 2 is `ats-011-lab-012`); the capstone is `ats-011-lab-SS0` (`ats-011-lab-010`); section 000 uses `ats-011-lab-001` and `ats-011-lab-000`.
- Playground names: module 1 is `ats-011-playground-<section>` (`010`); module N of 2 or more is `<section><N>` (`0102`).
- Grading scripts probe admission with `kubectl apply --dry-run=server`, or real creates for generate and cleanup labs. Each script prints `RESULT: PASS` at the end and `FAIL: ...` plus exit 1 on failure.
- New labs written without a cluster are marked UNTESTED in their `README.md` until someone runs them. Do not run or boot labs from a build session unless asked; use `astrona validate -c <dir>`, `bash -n` and `ruby -ryaml` as static checks.
- Quizzes are `quiz.yaml` question banks (`type: quiz`, `pass_score: 70` in `astrona.yaml`), one per section, plus `sections/final-domain-quiz.yaml`.

### Sections, modules, labs and playgrounds

| Section | Module | Parts | Playground | Lab | Lab title |
| --- | --- | --- | --- | --- | --- |
| 000 | 1. Policy Objects and Rule Anatomy | 3 | `ats-011-playground-000` | `ats-011-lab-001` | Policy Objects and Rule Anatomy Lab |
| 000 | Capstone | - | - | `ats-011-lab-000` | Policy Objects Capstone Lab |
| 010 | 1. Pattern-Based Validation | 3 | `ats-011-playground-010` | `ats-011-lab-011` | Pattern-Based Validation Lab |
| 010 | 2. Deny Rules and the Condition Vocabulary | 2 | `ats-011-playground-0102` | `ats-011-lab-012` | Deny Rules Lab |
| 010 | 3. Validation Anchors | 2 | `ats-011-playground-0103` | `ats-011-lab-013` | Validation Anchors Lab |
| 010 | 4. The podSecurity Subrule | 2 | `ats-011-playground-0104` | `ats-011-lab-014` | podSecurity Lab |
| 010 | 5. Assertion Trees and Manifest Verification | 2 | `ats-011-playground-0105` | `ats-011-lab-015` | Assertion Trees Lab |
| 010 | Capstone | - | - | `ats-011-lab-010` | Validation Rules Capstone Lab |
| 020 | 1. Preconditions | 2 | `ats-011-playground-020` | `ats-011-lab-021` | Preconditions Lab |
| 020 | Capstone | - | - | `ats-011-lab-020` | Preconditions Capstone Lab |
| 030 | 1. Background Scanning | 2 | `ats-011-playground-030` | `ats-011-lab-031` | Background Scanning Lab |
| 030 | Capstone | - | - | `ats-011-lab-030` | Background Scans Capstone Lab |
| 040 | 1. Mutation Rules | 2 | `ats-011-playground-040` | `ats-011-lab-041` | Mutation Rules Lab |
| 040 | 2. Per-Element Mutation and Idempotency | 2 | `ats-011-playground-0402` | `ats-011-lab-042` | Per-Element Mutation Lab |
| 040 | 3. Mutation Anchors | 2 | `ats-011-playground-0403` | `ats-011-lab-043` | Mutation Anchors Lab |
| 040 | Capstone | - | - | `ats-011-lab-040` | Mutation Rules Capstone Lab |
| 050 | 1. Generation Rules | 2 | `ats-011-playground-050` | `ats-011-lab-051` | Data-Based Generation Lab |
| 050 | 2. Generating for What Already Exists | 2 | `ats-011-playground-0502` | `ats-011-lab-052` | Generate Existing Lab |
| 050 | 3. Cloning Several Resources and generate foreach | 2 | `ats-011-playground-0503` | `ats-011-lab-053` | cloneList and generate foreach Lab |
| 050 | Capstone | - | - | `ats-011-lab-050` | Generation Rules Capstone Lab |
| 060 | 1. Image Signature & Attestation Verification | 2 | `ats-011-playground-060` | `ats-011-lab-061` | VerifyImage Rules Lab |
| 060 | 2. Attestors, Digests, and Registry Access | 2 | `ats-011-playground-0602` | `ats-011-lab-062` | Attestors and Digests Lab |
| 060 | 3. The images Variable and Image Extraction | 2 | `ats-011-playground-0603` | `ats-011-lab-063` | Image Extraction Lab |
| 060 | Capstone | - | - | `ats-011-lab-060` | VerifyImage Rules Capstone Lab |
| 070 | 1. Variables & API Calls in Policies | 2 | `ats-011-playground-070` | `ats-011-lab-071` | Live Pod-Quota Lab (context.apiCall) |
| 070 | 2. Context Beyond apiCall | 2 | `ats-011-playground-0702` | `ats-011-lab-072` | Context Entries Lab |
| 070 | 3. The Kyverno JMESPath Function Library | 2 | `ats-011-playground-0703` | `ats-011-lab-073` | JMESPath Functions Lab |
| 070 | Capstone | - | - | `ats-011-lab-070` | Variables & API Calls Capstone Lab |
| 080 | 1. JSON Patches | 3 | `ats-011-playground-080` | `ats-011-lab-081` | JSON Patches Lab |
| 080 | Capstone | - | - | `ats-011-lab-080` | JSON Patches Capstone Lab |
| 090 | 1. Autogen Rules | 3 | `ats-011-playground-090` | `ats-011-lab-091` | Autogen Rules Lab |
| 090 | Capstone | - | - | `ats-011-lab-090` | Autogen Rules Capstone Lab |
| 100 | 1. Cleanup Policies | 2 | `ats-011-playground-100` | `ats-011-lab-101` | Cleanup Policies Lab |
| 100 | Capstone | - | - | `ats-011-lab-100` | Cleanup Policies Capstone |
| 110 | 1. CEL in Kyverno Policies | 4 | `ats-011-playground-110` | `ats-011-lab-111` | CEL Validation Lab |
| 110 | 2. The CEL-Native Policy Family | 2 | `ats-011-playground-1102` | `ats-011-lab-112` | CEL-Native Policy Family Lab |
| 110 | Capstone | - | - | `ats-011-lab-110` | CEL Capstone |

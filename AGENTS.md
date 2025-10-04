## Purpose

Define how people and automation collaborate on the daftka project. This document clarifies roles, responsibilities, review expectations, and quality gates so contributions are fast, safe, and consistent with Elixir and OTP best practices.


## Contribution Workflow

1. Open a small, focused PR with a crisp description of the user-visible behavior change.
2. Include tests and docs in the same PR whenever possible.
3. Keep changes orthogonal; prefer multiple small PRs over one large PR.
4. Address review comments quickly; reviewers commit to timely feedback.

### Reviewing PR comments via CLI

Use the following to fetch PR review comments when triaging (replace placeholders):

```bash
gh api -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/ORG/REPO/pulls/PR_NUMBER/comments
```

## Quality Gates (Definition of Done)

All items must be satisfied before merge unless explicitly waived by a maintainer with rationale.

- **Types and Specs**
  - Public functions include `@spec` annotations; opaque types are preferred where appropriate.
  - Dialyzer runs clean (no new warnings) and types are meaningful, not `any`.
- **OTP Correctness**
  - Processes use OTP behaviors (e.g., `GenServer`, `Supervisor`) where applicable.
  - Failure handling follows crash-only design; supervisors own restart strategy.
- **Semantics**
  - Topic and partition semantics are respected and tested (ordering per partition, monotonic offsets, tenant isolation).
  - Delivery semantics are stated in docs and asserted in tests.
- **Testing**
  - Unit tests cover success and failure paths.
  - Property-based tests for core log/offset invariants.
  - Integration tests for Elixir client usage and JSON HTTP gateway semantics.
- **Docs**
  - ExDoc exposes public API with examples; README updated if user-facing.
  - Any new terms defined in the glossary.
- **Security & Multi-tenancy**
  - No tenant data leakage; tests enforce isolation. Minimal viable authn/z and input validation for gateway endpoints.
- **Performance (when relevant)**
  - Include a micro-benchmark or explain why not performance-sensitive.

## Style and Tooling

- **Formatting & Linting**: `mix format` clean; Credo issues addressed or documented.
- **Static Analysis**: Dialyzer required. If introducing new types, prefer type-safe constructors.
- **Testing**: `mix test` green; property tests seeded and deterministic where possible.
- **Docs**: `mix docs` builds without warnings.
- don't add needless accessors; be straightforward and simple, while remaining safe and correct

## Security and Privacy Expectations

- Avoid logging message bodies by default; prefer structured, redacted logs.
- Validate all external inputs at the boundary (HTTP gateway).
- Document data retention expectations; ensure deletion paths are testable.

## Communication

- Keep PRs small and descriptive; favor early feedback.

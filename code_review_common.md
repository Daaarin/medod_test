# Code Review Guidelines

These guidelines define the structure and expectations for automated code review using Codex. Follow them closely to ensure high-quality, actionable findings.

---

## Layers of Review

### 1. Architecture Review
**Goal:** Evaluate repository design and modularity.

Check for:
- Cyclic dependencies
- Misplaced responsibilities
- Over-coupled modules
- Duplicated domain logic
- Unclear boundaries between modules
- Legacy hotspots or outdated patterns

**Deliverable Tip:** Point to specific files, classes, or modules that violate design principles.

---

### 2. Security Review
**Goal:** Identify potential vulnerabilities.

Check for:
- Injection vulnerabilities (SQL, NoSQL, command injection)
- Authentication/authorization bypasses
- Unsafe deserialization
- Server-Side Request Forgery (SSRF)
- Secrets leakage (hardcoded credentials, tokens)
- Insecure file handling
- Privilege escalation paths

**Deliverable Tip:** Provide the exact line or function where the issue occurs, including a minimal reproduction if possible.

---

### 3. Test Coverage Review
**Goal:** Evaluate the quality and completeness of tests.

Check for:
- Untested critical code paths
- Flaky or unreliable tests
- Meaningless snapshot tests
- Missing integration or end-to-end tests
- Insufficient edge-case coverage

**Deliverable Tip:** Mention missing test scenarios and suggest concrete additions.

---

### 4. Performance Review
**Goal:** Detect performance bottlenecks and inefficient patterns.

Check for:
- N+1 database queries
- Excessive component rerenders
- Blocking synchronous I/O
- Memory leaks
- Inefficient loops or recursion
- Misuse of caching mechanisms

**Deliverable Tip:** Suggest alternative approaches or algorithms to improve performance.

---

### 5. Maintainability Review
**Goal:** Ensure code is clean, readable, and maintainable.

Check for:
- Duplicate abstractions
- Dead or unreachable code
- Over-engineering or unnecessary complexity
- Poor naming conventions
- Hidden side effects
- Large functions/classes that need refactoring

**Deliverable Tip:** Recommend clear refactors and provide small, actionable steps.

---

## Structured Findings Format

All issues must be reported strictly using this structure:
Severity: Critical | High | Medium | Low
Category: Architecture | Security | Testing | Performance | Maintainability
File: path/to/file.ext
Problem: Clear, concise description of the issue
Why it matters: Impact of the problem
Suggested fix: Specific action or code snippet to resolve


**Rules:**
- Only report issues with concrete evidence from the code.
- Never speculate or report potential issues without code backing.
- Always reference exact files, classes, or functions.
- Be strict and precise.

---

## Review Workflow

1. Ask the user for review depth:
    - **full** → all layers (1–5)
    - **fast** → layers 4 & 5 (Performance + Maintainability)
    - **custom** → user-specified subset of layers
2. Perform the review using `/review`.
3. Execute reviews according to the user’s depth selection.
4. Concatenate and return structured results from all executed layers.

---

## Notes for Codex Optimization
- Encourage short, actionable findings rather than vague observations.
- Include code snippets or line references wherever possible.
- Use consistent severity levels across all layers for easier prioritization.
- Keep output strictly structured to allow automated parsing.
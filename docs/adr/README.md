Last Modified: 08/24/2026 (1787587709) by amonrit

# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records — structured documents that explain major architectural decisions, their rationale, consequences, and alternatives.

## What is an ADR?

An ADR is a short markdown file that:
- **Documents a decision** made about the system architecture
- **Explains the context** (problems we were trying to solve)
- **Justifies the choice** (why we picked this approach)
- **Lists consequences** (trade-offs and benefits)
- **Compares alternatives** (what we didn't choose and why)

ADRs are useful for:
✅ New developers understanding "why" things are designed this way  
✅ Code reviewers evaluating design consistency  
✅ Architects making future decisions  
✅ Troubleshooting when things go wrong  

## Current ADRs

### ADR-001: Structured Concurrency
**Status:** ✅ ACCEPTED (Phase 7)  
**Topic:** Using StateActor for thread-safe state instead of @Published  
**Impact:** All state management uses actor isolation + AsyncStream  
**Read:** [ADR-001-structured-concurrency.md](./ADR-001-structured-concurrency.md)

**Key Quote:**
> StateActor provides compile-time thread safety, automatic task cancellation, and better alignment with Swift best practices than @Published properties.

### ADR-002: Centralized Retry Logic
**Status:** ✅ ACCEPTED (Phase 4)  
**Topic:** Using RetryOrchestrator for consistent retry behavior  
**Impact:** All network calls use exponential backoff + configurable strategies  
**Read:** [ADR-002-retry-orchestrator.md](./ADR-002-retry-orchestrator.md)

**Key Quote:**
> Centralizing retry logic ensures consistency, testability, and enables metrics across all network operations.

### ADR-003: Dependency Injection via APIClientProvider
**Status:** ✅ ACCEPTED (Phase 5)  
**Topic:** Using provider protocol for API client creation  
**Impact:** All services accept APIClientProvider, enabling easy testing without network  
**Read:** [ADR-003-dependency-injection.md](./ADR-003-dependency-injection.md)

**Key Quote:**
> Protocol-based DI decouples services from HTTP implementation, making code testable and flexible.

### ADR-004: Coordinator Pattern for Navigation & DI
**Status:** ✅ ACCEPTED (implemented)  
**Topic:** Centralizing navigation state and ViewModel construction  
**Impact:** `AppCoordinator` + `DIContainer` are the only place ViewModels get built; Views never construct their own  
**Read:** [ADR-004-coordinator-navigation.md](./ADR-004-coordinator-navigation.md)

**Key Quote:**
> One coordinator with an enum-based route list is enough for this app's navigation depth — no need for the heavier traditional UIKit Coordinator.

## How to Read an ADR

1. **Start with Status** — Is this decision still active?
2. **Read Context** — What problem were we solving?
3. **Understand Decision** — What did we choose?
4. **Check Consequences** — What are the trade-offs?
5. **Compare Alternatives** — Why not other approaches?

## Using ADRs in Code Review

When reviewing code:

1. **Is the design consistent with ADRs?**
   ```
   ✅ Uses StateActor for state? (follows ADR-001)
   ✅ Wraps network calls in RetryOrchestrator? (follows ADR-002)
   ✅ Accepts APIClientProvider? (follows ADR-003)
   ```

2. **Does new architecture need an ADR?**
   ```
   If you're making a major decision, document it as a new ADR
   ```

3. **Reference ADRs in comments**
   ```swift
   // StateActor usage per ADR-001
   @MainActor
   actor MyStateActor { /* ... */ }
   ```

## Creating a New ADR

When you need to make a significant architectural decision:

### Step 1: Check existing ADRs
Ensure your decision isn't already documented.

### Step 2: Create the file
```bash
touch docs/adr/ADR-00N-short-title.md
```

### Step 3: Use the template
```markdown
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME

# ADR-00N: Title of Decision

## Status
PROPOSED | ACCEPTED | SUPERSEDED | REJECTED

## Context
What problem were we facing? Why did we need to make a decision?

## Decision
What did we decide to do?

## Implementation
How does it work? Code examples?

## Consequences
### ✅ Advantages
### ⚠️ Trade-offs

## Alternatives Considered
What else could we have done?

## Related Decisions
Links to other ADRs

## References
Links to external resources

---
**Follows:** Which phase/issue  
**Supersedes:** Any previous decisions  
**Last Reviewed:** Date  
```

### Step 4: Get feedback
- Link to the ADR in your PR
- Ask for architectural review
- Get team consensus

### Step 5: Update DOCUMENTATION.md
Add reference to the new ADR in the master index.

## Decision Tree: When to Use What

```
Making a decision about...

State Management?
  → See ADR-001 (Structured Concurrency)
     Use StateActor instead of @Published

Network Resilience?
  → See ADR-002 (Retry Orchestrator)
     Use RetryOrchestrator for retries

Testing & Flexibility?
  → See ADR-003 (Dependency Injection)
     Use APIClientProvider for DI

Concurrency?
  → See ADR-001 (mentions Task-based polling)
     Use Task.sleep instead of Timer

Navigation or where a ViewModel comes from?
  → See ADR-004 (Coordinator)
     Get it from AppCoordinator, don't construct it in a View

Something new?
  → Create a new ADR!
```

## Summary Table

| ADR | Topic | Decision | Status |
|-----|-------|----------|--------|
| 001 | State | Use StateActor + AsyncStream, mirrored into `@Observable` | ✅ Active |
| 002 | Retry | Use RetryOrchestrator | ✅ Active |
| 003 | DI | Use APIClientProvider | ✅ Active |
| 004 | Navigation/DI | Use AppCoordinator + DIContainer | ✅ Active |

## Relationship Between ADRs

```
ADR-001 (Structured Concurrency)
  ↓ enables
ADR-002 (Retry Orchestrator)
  ↓ enables
ADR-003 (Dependency Injection)
  ↓ composed by
ADR-004 (Coordinator)
```

All four work together:
1. **StateActor** manages state safely (ADR-001)
2. **RetryOrchestrator** makes network calls resilient (ADR-002)
3. **APIClientProvider** makes everything testable (ADR-003)
4. **AppCoordinator/DIContainer** wire ViewModels (built from 1-3) into the right screen (ADR-004)

## Reviewing an ADR

Before accepting a new ADR, check:

- [ ] **Status is clear** — PROPOSED, ACCEPTED, or SUPERSEDED
- [ ] **Context is explained** — Why did we need this decision?
- [ ] **Decision is specific** — What exactly are we doing?
- [ ] **Consequences listed** — Benefits AND trade-offs
- [ ] **Alternatives considered** — Why not other approaches?
- [ ] **Related ADRs linked** — How does this fit with others?
- [ ] **Implementation shown** — Code examples or patterns
- [ ] **References provided** — Links to justification

## FAQ

**Q: Can an ADR be changed later?**  
A: Yes! Mark it as SUPERSEDED and create a new ADR explaining why.

**Q: Who approves an ADR?**  
A: Architectural leads or team consensus during code review.

**Q: How long should an ADR be?**  
A: 1-2 pages. Concise but complete.

**Q: What if we disagree with an ADR?**  
A: Create a new ADR explaining the alternative, then discuss as a team.

**Q: Do ADRs apply to all code?**  
A: They're guidelines for new code. Legacy code can follow old patterns until refactored.

## Links

- **[ARCHITECTURE.md](../ARCHITECTURE.md)** — Complete system design
- **[PATTERN-CHEAT-SHEET.md](../PATTERN-CHEAT-SHEET.md)** — Templates for using every pattern in these ADRs

## Quick Links by Topic

### State Management
→ ADR-001 (StateActor)

### Network Calls
→ ADR-002 (RetryOrchestrator) + ADR-003 (APIClientProvider)

### Testing
→ ADR-003 (Dependency Injection)

### Concurrency
→ ADR-001 (Structured Concurrency with Tasks)

### Navigation & ViewModel Construction
→ ADR-004 (Coordinator)

---

**ADR Directory Created:** August 2026 (Phase 11)  
**Current Count:** 4 ADRs  
**Next Review:** August 2027

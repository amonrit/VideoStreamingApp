Last Modified: 08/10/2026 (1786359014) by amonrit

# Commit Guide

How to write good commit messages for this project.

---

## Quick Rules

1. **Use the template**: `git commit` (auto-loads .gitmessage)
2. **Type first**: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`, `style:`, `ci:`
3. **Keep subject ≤50 chars**: First line is a headline
4. **Imperative mood**: "add" not "added", "fix" not "fixed"
5. **Capitalize type, lowercase subject**: `feat(scope): description`
6. **One commit = one logical change**: Don't mix features, fixes, and refactors
7. **No period at end of subject**: `feat: add pause button` ✅ (not `feat: add pause button.` ❌)

---

## Format (Required)

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type

Required. One of:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `refactor` - Code restructuring (no behavior change)
- `perf` - Performance improvement
- `test` - Test additions/changes
- `chore` - Build, config, dependencies
- `style` - Formatting (no code logic change)
- `ci` - CI/CD pipeline changes

### Scope

Optional but recommended. Area of change:
- `(playback)` - Playback-related
- `(ui)` - User interface
- `(server)` - Streaming server
- `(config)` - Configuration
- `(docs)` - Documentation
- `(test)` - Testing

### Subject

- 50 characters or less
- Imperative mood ("add" not "added")
- No period at the end
- Clear and descriptive

### Body (Optional but Recommended)

- Wrap at 72 characters
- Explain **what** and **why**, not **how**
- Use bullet points for multiple changes
- Leave blank line between subject and body

### Footer (Optional)

- Reference issues: `Closes #42` or `Fixes #42`
- Note breaking changes: `BREAKING CHANGE: description`
- ❌ **Do NOT use** `Co-Authored-By:` footer — forbidden

---

## Examples

### ✅ GOOD Commits

**Simple fix:**
```
fix(playback): resolve HLS segment timeout

Increase timeout from 2s to 3s to handle slower networks.
This fixes buffering issues on cellular connections.
```

**New feature:**
```
feat(playback): add pause button

- Add pause() method to PlaybackViewModel
- Create UI pause button in VideoPlayerView
- Update debug panel to show pause state

Closes #42
```

**Documentation:**
```
docs: update DEVELOPMENT.md with debugging tips
```

**Refactor:**
```
refactor(viewmodel): simplify error handling

Extract repeated error logic into separate method.
Makes code more maintainable and testable.

Related to #38
```

**Performance:**
```
perf(ui): optimize ContentView rendering

Reduce re-renders by memoizing expensive calculations.
Improves performance from 500ms to 100ms.
```

### ❌ BAD Commits

**Too vague:**
```
fix: stuff
❌ "stuff" doesn't say what was fixed
```

**Too long subject:**
```
feat: add ability to pause and resume playback and also show current time in the player view
❌ Should be: feat(playback): add pause/resume controls and time display
```

**Wrong tense:**
```
feat: added pause button
❌ Should be: feat: add pause button (imperative, not past tense)
```

**Multiple unrelated changes:**
```
feat: add pause button, fix UI bug, update docs, refactor ViewModel
❌ Should be 4 separate commits
```

**No scope:**
```
feat: improvements
❌ Improvements where? Should be: feat(playback): add pause button
```

**Period at end:**
```
feat: add pause button.
❌ Remove period: feat: add pause button
```

---

## Commit Size Rules

### ✅ Atomic Commits (One logical change)

**Good:**
```
1. feat(ui): add pause button
2. feat(viewmodel): implement pause logic
3. test: add pause button tests
4. docs: update feature list
```

**Why:** Each commit can be reviewed independently, reverted independently, and bisected if needed.

### ❌ Monolithic Commits (Multiple unrelated changes)

**Bad:**
```
1. feat: add pause button, fix memory leak, update docs, refactor ViewModel
```

**Why:** Can't revert just the pause button without losing other fixes. Hard to review. Hard to debug.

---

## What Makes a Good Commit Message

### 1. Context

Reader should understand **what** changed and **why** in 10 seconds.

```
✅ GOOD:
feat(playback): add pause button

Users requested ability to pause/resume playback.
Implemented via PlaybackViewModel pause() method.

❌ BAD:
feat: button stuff
```

### 2. Why Matters More Than How

```
✅ GOOD:
refactor(viewmodel): simplify retry logic

Old logic had 50 lines of nested conditions.
New version uses guard statements for clarity.
Improves maintainability without changing behavior.

❌ BAD:
refactor: changed some code
```

### 3. Connect to Issues

```
✅ GOOD:
fix(streaming): resolve buffering on slow networks

Increase timeout from 2s to 3s. Tests on LTE show
improved stability without sacrifice.

Closes #123
Fixes #456

❌ BAD:
fix: buffering
```

### 4. Be Honest About Impact

```
✅ GOOD:
perf(ui): reduce rendering time

ContentView was re-rendering 50x per second.
Wrapped expensive calculations in useMemo.
Reduces to 2-3 re-renders. Improves performance 50%.

❌ BAD:
perf: make it faster
```

---

## By Feature Type

### Features (feat:)

```
feat(playback): add play speed control

Users can select from: 0.5x, 1x, 1.5x, 2x
- Add speedOptions to PlaybackViewModel
- Create SpeedSelectorView component
- Persist user preference in UserDefaults

Closes #42
```

**Guidelines:**
- Describe what users can now do
- List implementation files/changes
- Link to issue if it exists
- Usually 1-2 days of work

### Bug Fixes (fix:)

```
fix(server): resolve HLS manifest 404 errors

Root cause: segments generated after manifest requested.
Solution: Add 2-second delay before manifest generation.
Now stream always available when client asks.

Fixes #789
```

**Guidelines:**
- Describe the problem (what users saw)
- Explain root cause (why it happened)
- Describe the fix (what changed)
- Reference issue

### Documentation (docs:)

```
docs: add AI workflow guide with examples

Explains how to use Claude Code effectively:
- When to use /swift-ios-expert vs /streaming-expert
- How to structure prompts for best results
- ROI: save 180+ hours/year with proper usage
```

**Guidelines:**
- Describe what docs were added/updated
- One sentence on why it matters
- Short and sweet

### Refactoring (refactor:)

```
refactor(viewmodel): extract observer setup to Worker

Moved setupKVOObservers() from PlaybackViewModel
to VideoPlayerWorker for reusability.

Behavior unchanged, improves code organization.
```

**Guidelines:**
- Describe what moved/changed
- Explain why (testability, reusability, clarity)
- State that behavior is unchanged
- NO functional changes

### Tests (test:)

```
test: add PlaybackViewModel pause tests

Add tests for:
- pause() stops playback
- pause() then play() resumes
- pause() while buffering
- Multiple rapid pause/play cycles
```

**Guidelines:**
- List test scenarios added
- Keep them focused on one thing
- Related to recent feature commit if applicable

### Performance (perf:)

```
perf(ui): optimize ContentView rendering

Problem: ContentView re-rendered 200x on state change
Solution: Extract expensive calculation to computed property
Result: Reduce renders to 2-3, improve from 500ms to 50ms

Measured with Xcode Instruments Time Profiler.
```

**Guidelines:**
- Problem: What was slow
- Metric: How much (50ms → 5ms, 200 renders → 5)
- Tool: How you measured it (profiler, benchmark, etc.)

---

## Commit Workflow

### Before Committing

1. **One logical change per commit**
   ```bash
   git add <related-files-only>
   git commit
   ```

2. **Test passes**
   ```bash
   make test-app
   ```

3. **Code review checklist**
   - [ ] Follows MVVM pattern
   - [ ] No memory leaks ([weak self])
   - [ ] Thread-safe
   - [ ] Tests included
   - [ ] Good commit message

### Writing the Message

1. Run: `git commit` (loads .gitmessage template)
2. Fill in type, scope, subject
3. Add body explaining why
4. Add footer with issue reference
5. Save and close editor

### After Committing

1. Verify message: `git log -1`
2. Perfect it? `git commit --amend`
3. Push: `git push`

---

## Command Reference

```bash
# Use template
git commit

# Edit last commit message
git commit --amend

# View last commit
git log -1

# View last 5 commits
git log -5 --oneline

# View commit details
git show <commit-hash>

# Search commits by message
git log --grep="pause button"

# View by author
git log --author="name"
```

---

## When to Split Commits

**Split when:**
- [ ] Changes affect different components (UI + logic)
- [ ] One change is a fix, another is refactor
- [ ] One change is docs, another is code
- [ ] Multiple independent features

**Example (should be 2 commits):**
```
❌ BAD (one commit):
feat: add pause button, fix memory leak, update docs

✅ GOOD (three commits):
1. fix(viewmodel): fix memory leak in observer cleanup
2. feat(playback): add pause button
3. docs: update README with pause feature
```

---

## Tips for Better Commits

### 1. Commit Frequently

Small, logical commits are easier to review and debug.

```
✅ Good:
1. refactor: extract VideoPlayerWorker setup
2. feat: add pause button
3. test: add pause button tests
4. docs: update feature list

❌ Bad:
1. Everything in one commit
```

### 2. Use Present Tense

Imagine: "If applied, this commit will **[your message]**"

```
✅ add pause button
❌ added pause button
❌ add pause buttons (plural when one)
```

### 3. Think Like a Future Developer

Would you understand this commit 6 months from now?

```
✅ Specific and clear
"feat: add pause button with keyboard shortcut support"

❌ Vague
"feat: UI improvements"
```

### 4. One Feature Per Commit

```
❌ BAD:
feat: pause button, quality selector, and full screen mode

✅ GOOD:
1. feat(playback): add pause button
2. feat(quality): add quality selector
3. feat(fullscreen): add fullscreen button
```

### 5. Separate Concerns

```
❌ BAD:
feat(ui): add pause button and fix buffering issue

✅ GOOD:
1. fix(playback): resolve buffering on slow networks
2. feat(ui): add pause button
```

---

## Issue References

```
# Close issue
Closes #42
Fixes #42

# Related to issue
Related to #42
See #42

# Multiple issues
Closes #42, #43
Fixes #42, #43

# In body or footer
This commit addresses the buffering issue reported in #42.

Closes #42
```

---

## Final Checklist

Before `git push`, verify:

- [ ] Commit message follows format
- [ ] Subject ≤50 characters
- [ ] Imperative tense (add, not added)
- [ ] No period at end of subject
- [ ] Body explains why (if needed)
- [ ] Issue referenced (if applicable)
- [ ] Tests pass
- [ ] One logical change
- [ ] No unrelated files included

---

## Examples in This Project

Check past commits:
```bash
git log --oneline | head -20
git show <commit-hash>
```

Recent good examples:
- `feat(config): add environment template` - Clear scope and action
- `fix: resolve MediaMTX configuration error` - Specific problem solved
- `docs: add AI workflow guide` - Purpose clear

---

**Remember:** A good commit message is a gift to your future self and your team. Take 30 seconds to write it clearly.
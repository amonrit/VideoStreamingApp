Last Modified: 08/17/2026 (1786899911) by amonrit

# AI Workflow Guide

How to work effectively with Claude Code, Cursor IDE, and GitHub Copilot on this project.

---

## Quick Start: Using Claude Code

### First Time Setup (1 minute)

1. Open project in Claude Code
2. It auto-loads `.claude/settings.json`
3. Antigravity builds semantic index (~60 seconds)
4. Ready to use! ✅

### Ask AI Questions

```
Using specialized agents:
  /swift-ios-expert "Review PlaybackViewModel for memory leaks"
  /streaming-expert "Debug: Stream keeps buffering"

General questions:
  "Where is PlaybackViewModel used in the codebase?"
  "Show me the data flow from VideoStreamListView to AVPlayer"
  "Find all references to setupObservers()"
  "What's the retry logic in loadStream()?"
```

---

## Common AI Tasks (Do's & Don'ts)

### Code Review

❌ **Don't:** "Review this code"
✅ **Do:** "Review PlaybackViewModel.swift against the MVVM pattern. Check for memory leaks using [weak self]"

**Why:** AI needs specific criteria to review against.

---

### Performance

❌ **Don't:** "Make it faster"
✅ **Do:** "VideoStreamListView takes 500ms to render. Profile using Instruments. What's the bottleneck and how to optimize?"

**Why:** Context helps AI give targeted advice.

---

### Testing

❌ **Don't:** "Write tests"
✅ **Do:** "Write XCTest for PlaybackViewModel.loadStream(). Include: valid URL, invalid URL, network timeout. Use mocking."

**Why:** AI knows what tests you actually need.

---

### Architecture

❌ **Don't:** "Explain MVVM"
✅ **Do:** "In this project, explain how data flows from VideoStreamListView → PlaybackViewModel → AVPlayer when loadStream() is called"

**Why:** Project-specific context makes answers relevant.

---

## Code Review with AI

### Workflow

1. Make changes in your editor
2. Ask Claude Code:
   ```
   "Review my changes in steam/ViewModels/PlaybackViewModel.swift
   against these criteria:
   - MVVM pattern adherence
   - Memory safety ([weak self] usage)
   - Thread safety
   - Error handling
   - Code simplicity"
   ```
3. AI analyzes using Antigravity (understands relationships)
4. Shows you patterns, issues, improvements
5. You decide what to apply

### What to Ask

✅ "Does this follow MVVM pattern?"
✅ "Are there memory leaks with closures?"
✅ "Is this thread-safe?"
✅ "Can this be simplified?"
✅ "What tests should I write?"
✅ "Is there a better way to do this?"

### What NOT to Ask

❌ "Does this look good?" (too vague)
❌ "Fix this" (AI doesn't know what to fix)
❌ "Make it production-ready" (subjective)

---

## Debugging with AI

### Scenario: "Stream keeps buffering on slow networks"

Ask Claude Code step-by-step:

1. **Trace the state:**
   ```
   "Trace all places where isLoading changes in PlaybackViewModel.
   Show the complete flow when a stream starts buffering."
   ```

2. **Understand the retry logic:**
   ```
   "Show me the retry logic in loadStream().
   Is it optimal for slow networks?
   Current timeout is 3s - should it be longer?"
   ```

3. **Compare alternatives:**
   ```
   "Compare HLS vs RTSP for this use case.
   Which is better for slow networks and why?
   What are the trade-offs?"
   ```

4. **Get optimization tips:**
   ```
   "Based on the architecture, how could we reduce buffering
   without sacrificing playback quality?"
   ```

### Why This Works

Each question builds on the last. AI learns your context progressively.
Together you debug systematically instead of guessing.

---

## Refactoring with AI

### Before You Refactor

Ask AI for impact analysis:

```
"I want to rename setupObservers() to configureObservers().
Show me:
1. Every place this method is called
2. What would break if I rename it
3. Are there any tests I need to update?"
```

AI will:
- Find all references (using Antigravity)
- Show impact scope
- Suggest tests to update
- Warn about hidden dependencies

### Safe Refactoring Steps

1. Ask: "What would break if I change X?"
2. Look at AI's answer
3. Make change carefully
4. Run tests
5. Ask: "Did I miss anything?"

---

## Architecture Questions

### "Should we add Quality Selection feature?"

1. **Understand effort:**
   ```
   "What's the effort to implement Quality Selection feature?
   Where would it fit in PlaybackViewModel?"
   ```

2. **Design the addition:**
   ```
   "How would we implement quality switching without
   interrupting playback? Show me the code flow."
   ```

3. **Plan the work:**
   ```
   "What new Workers or Methods would we need?
   What's the minimal viable implementation?"
   ```

### "Is this the right pattern?"

```
"I implemented X this way. Is this following our MVVM pattern?
Show me an alternative approach and compare trade-offs."
```

AI will:
- Validate against MVVM
- Show 1-2 alternatives
- Explain pros/cons of each
- Recommend best approach

---

## When NOT to Use AI

### ❌ Trivial changes (1-2 lines)
Just edit manually. Don't waste AI cycles.

### ❌ You don't understand the code
Read/learn first, then ask AI.
Never submit code you don't understand.

### ❌ Security/Auth related
Review carefully with human.
Don't blindly trust AI output for sensitive code.

### ❌ Simple typos/formatting
Fix manually. Too trivial for AI.

### ❌ You're not sure what you want
Think first. Ask AI when you have direction.

---

## Tools Available

### Claude Code (`.claude/`)

**Antigravity (Semantic Code Understanding)**
- Understands MVVM relationships
- Maps data flow
- Finds code references
- Shows which Views observe which ViewModel properties

**2 Specialized Agents**
- `/swift-ios-expert` - MVVM, SwiftUI, AVFoundation
- `/streaming-expert` - MediaMTX, Docker, protocols

**Guides Included**
- `.claude/instructions/swift-style.md` - Coding standards
- `.claude/antigravity-guide.md` - Deep code understanding

### Cursor IDE (`.cursorrules`)

- Context-aware autocomplete
- Code generation from comments
- Refactoring assistance
- Automatic formatting

**Use like:**
```
// Generate a test for this function:
func testLoadStreamWithValidURL() {
    // Start typing and Cursor suggests the rest
}
```

### GitHub Copilot (`.github/copilot-instructions.md`)

- In-editor suggestions while typing
- Comment-to-code generation
- Test generation
- Method completion

---

## Best Practices for Prompts

### ✅ Be Specific

```
GOOD: "In PlaybackViewModel, why does loadStream() create
a new observer each time instead of reusing one?"

BAD: "Why is this code like this?"
```

### ✅ Provide Context

```
GOOD: "This is causing memory issues when switching streams.
How can we fix it?"

BAD: "Fix this."
```

### ✅ Ask for Trade-offs

```
GOOD: "What's the performance impact of adding this feature?
Show me the analysis."

BAD: "Add this feature."
```

### ✅ Request Alternatives

```
GOOD: "Show me 2 ways to implement this. Compare pros/cons."

BAD: "How do I implement this?"
```

### ✅ Follow Up

```
GOOD:
  Q1: "How does buffering work?"
  Q2: "Why does it buffer on slow networks?"
  Q3: "How to reduce buffering?"
  
BAD: One question and done.
```

---

## Example Workflows

### Workflow 1: Adding a Feature

1. Ask for design:
   ```
   "I want to add a pause button. Show me how it fits
   into PlaybackViewModel and UI flow."
   ```

2. Get code structure:
   ```
   "Write the PlaybackViewModel methods I need.
   Then show me the UI code."
   ```

3. Review for quality:
   ```
   "Review my implementation against MVVM pattern.
   Check for memory leaks and threading issues."
   ```

4. Add tests:
   ```
   "Write XCTest for pause/play toggle."
   ```

5. Deploy:
   ```
   "Any edge cases I'm missing? Production checklist?"
   ```

### Workflow 2: Debugging an Issue

1. Describe the problem:
   ```
   "App crashes when switching streams rapidly."
   ```

2. Get diagnosis:
   ```
   "Analyze crash logs. Where's the memory leak?
   Show me the code path."
   ```

3. Understand root cause:
   ```
   "Why does switching streams leak memory?
   Where are we keeping references?"
   ```

4. Fix it:
   ```
   "How to fix it? Show alternative implementations."
   ```

5. Verify:
   ```
   "Any other places with this pattern?"
   ```

### Workflow 3: Performance Optimization

1. Identify bottleneck:
   ```
   "VideoStreamListView rendering is slow. Profile shows
   500ms in [method name]. Why?"
   ```

2. Understand impact:
   ```
   "What's the bottleneck? Is it UI or logic?"
   ```

3. Get solutions:
   ```
   "How to optimize? Show me 2-3 approaches."
   ```

4. Compare:
   ```
   "Which approach is best for this architecture?
   Trade-offs?"
   ```

5. Implement:
   ```
   "Write the optimized code."
   ```

---

## AI + Manual Work Balance

**Use AI for:**
- Understanding architecture
- Code review
- Debugging strategy
- Testing strategy
- Optimization ideas

**Do manually:**
- Simple edits
- Typing code you understand
- Testing the changes
- Final validation

**Work together:**
- AI suggests, you implement
- You code, AI reviews
- Back-and-forth for complex problems

---

## Tips for Maximum Productivity

### 1. Provide Context Files

When asking about a class:
```
"Here's PlaybackViewModel.swift:
[paste relevant code]

How would you optimize this?"
```

AI can give better advice with actual code to read.

### 2. Use Follow-ups

Don't ask everything in one message:
```
Q1: "How does error handling work?"
   → Read answer
Q2: "Why do we retry 3 times?"
   → Read answer
Q3: "Should we increase retries for slow networks?"
   → Get specific advice based on context
```

### 3. Ask "Why" Questions

```
"Why do we use @StateObject in VideoStreamListView?"
"Why is there a 3-second timeout?"
"Why do we use [weak self] in closures?"
```

Understanding WHY makes you better at coding.

### 4. Share Error Messages

When debugging:
```
"Getting this error: [paste full error]
Stack trace: [paste stack trace]
What's happening?"
```

AI can diagnose from actual error messages.

### 5. Use Agents Intentionally

```
Use /swift-ios-expert for:
  - MVVM questions
  - SwiftUI issues
  - Memory/threading

Use /streaming-expert for:
  - Server configuration
  - Protocol questions
  - Docker/network issues
```

---

## ROI (Return on Investment)

### Time Savings Per Month

| Task | Without AI | With AI | Saved |
|------|-----------|---------|-------|
| Code review (5 x 1hr) | 5 hrs | 1 hr | 4 hrs |
| Debugging (4 x 2hrs) | 8 hrs | 3 hrs | 5 hrs |
| Architecture (2 x 3hrs) | 6 hrs | 2 hrs | 4 hrs |
| Testing (3 x 1hr) | 3 hrs | 1 hr | 2 hrs |
| **Monthly Total** | **22 hrs** | **7 hrs** | **15 hrs** ✅ |

**Annual Savings: 180 hours!** 🚀

### Quality Improvements

- ✅ Fewer bugs (caught in review)
- ✅ Better architecture (guided by AI)
- ✅ More tests (AI suggests edge cases)
- ✅ Faster debugging (systematic approach)
- ✅ Higher code standards (consistent review)

---

## Troubleshooting AI Responses

### "AI gave me bad code"

**Reason:** You didn't provide enough context
**Solution:** Include more code, clearer requirements, or ask for alternatives

### "AI didn't understand my question"

**Reason:** Too vague or unclear
**Solution:** Rephrase with specific examples and context

### "AI answer doesn't work"

**Reason:** Might be outdated or project-specific issue
**Solution:** Ask "Why didn't this work?" for better answer

### "AI keeps suggesting same thing"

**Reason:** You're asking the same way
**Solution:** Try different angle or provide contradicting context

---

## Next Steps

1. Read `.claude/antigravity-guide.md` for deep code understanding
2. Read `.claude/instructions/swift-style.md` for coding standards  
3. Read `ARCHITECTURE.md` to understand project deeply
4. Start using these workflows on real tasks
5. Adjust based on what works for you

---

**Remember:** AI is most powerful when used strategically, not for every keystroke. Think first, ask smart questions, review carefully.

Happy coding! 🚀
Last Modified: 08/10/2026 (1786502400) by amonrit

# Commit Workflow Guide

This guide explains how to use all the commit tools together to write great commits.

---

## 🎯 Your Commit Tools

You now have **3 ways** to get commit guidance:

### 1. **Auto-Reminder** (Every Commit)
When you run `git commit`, you'll see:
```
📖 COMMIT GUIDE REMINDER

Quick rules:
  1. Use template: type(scope): subject ≤50 chars
  2. Imperative mood: "add" not "added"
  3. One commit = one logical change
  4. See COMMIT_GUIDE.md for full details
```

**How it works:** Git hook automatically shows this before your editor opens.

---

### 2. **Quick Reference Script**
Before committing, check the pattern for your change:

```bash
# By scenario
./scripts/commit-help.sh feature
./scripts/commit-help.sh fix
./scripts/commit-help.sh docs
./scripts/commit-help.sh refactor
./scripts/commit-help.sh test
./scripts/commit-help.sh perf

# Show all scenarios
./scripts/commit-help.sh all

# Show quick tips
./scripts/commit-help.sh tips

# Show help
./scripts/commit-help.sh
```

**Example:**
```bash
$ ./scripts/commit-help.sh feature

📋 FEATURE (feat:) COMMIT

Use when: Adding a new feature or capability

Example:
feat(playback): add pause/resume controls

- Add pause() method to PlaybackViewModel
- Create pause button in VideoPlayerView
- Update debug panel to show current state

Closes #42
```

**Use this:** When you're not sure about the format for your specific change.

---

### 3. **Comprehensive Guide**
For detailed information:

```bash
# Open the full guide
open COMMIT_GUIDE.md

# Or read it in your editor
cat COMMIT_GUIDE.md
```

**Contains:**
- All 9 commit types
- Real examples
- Good vs bad commits
- Tips for better messages
- Workflow checklist

---

## 📋 Workflow: Before, During, After

### **Before Committing**

```bash
# 1. Make your changes
# (edit files, test them)

# 2. Check what type of commit this is
./scripts/commit-help.sh feature  # or fix, docs, etc.

# 3. Read the example
# Compare your changes to the example format
```

### **During Committing**

```bash
# Run commit
git commit

# You'll see:
# 1. Reminder message (appears automatically)
# 2. Template opens in editor (.gitmessage)
# 3. Fill in: type(scope): subject
# 4. Add body explaining why
# 5. Add footer with issue reference
# 6. Save and close
```

### **After Committing**

```bash
# Verify your commit
git log -1

# Should show:
# feat(scope): clear subject line
# 
# Explanation of why

# Perfect? Push it!
git push

# Need to fix? Amend it
git commit --amend
```

---

## 🎯 Quick Decision Tree

**My change is...**

→ **Adding a feature?**
```bash
./scripts/commit-help.sh feature
# Use: feat(scope): description
```

→ **Fixing a bug?**
```bash
./scripts/commit-help.sh fix
# Use: fix(scope): description
```

→ **Just updating docs?**
```bash
./scripts/commit-help.sh docs
# Use: docs: description
```

→ **Refactoring (no behavior change)?**
```bash
./scripts/commit-help.sh refactor
# Use: refactor(scope): description
```

→ **Adding tests?**
```bash
./scripts/commit-help.sh test
# Use: test: description
```

→ **Improving performance?**
```bash
./scripts/commit-help.sh perf
# Use: perf(scope): description
```

→ **Build/config/dependency changes?**
```bash
./scripts/commit-help.sh chore
# Use: chore: description
```

→ **Just formatting code?**
```bash
./scripts/commit-help.sh style
# Use: style: description
```

→ **CI/CD pipeline changes?**
```bash
./scripts/commit-help.sh ci
# Use: ci: description
```

---

## 📚 Files You Have

| File | Purpose | When to Use |
|------|---------|-----------|
| `.gitmessage` | Template loaded on `git commit` | Always loaded automatically |
| `COMMIT_GUIDE.md` | Comprehensive guide (560 lines) | When you need full details |
| `scripts/commit-help.sh` | Quick reference by scenario | Before committing |
| `.git/hooks/prepare-commit-msg` | Auto-reminder message | Every `git commit` |

---

## ⚡ Fastest Workflow

**TL;DR (30 seconds per commit):**

```bash
# 1. Make changes
# 2. Quick check
./scripts/commit-help.sh fix   # or feature, docs, etc.

# 3. Commit (reminder shows automatically)
git commit

# 4. Fill in template
# type(scope): subject
# [blank line]
# Explanation
# [blank line]
# Closes #42

# 5. Save and push
git push
```

**Time invested:** ~2 minutes = Better history for future you

---

## 💡 Pro Tips

### 1. Aliasing for Speed
Add to your shell config (`~/.zshrc` or `~/.bash_profile`):

```bash
alias ch='./scripts/commit-help.sh'
alias cm='git commit'
```

Now:
```bash
ch feature    # Show feature template
cm            # Commit with reminder
```

### 2. Commit Frequently
Don't wait until the end of the day. Commit after each logical change:

```
✅ GOOD:
1. fix: resolve timeout issue
2. feat(playback): add pause button
3. test: add pause tests
4. docs: update README

❌ BAD:
1. feat: pause button, fixed timeout, added tests, updated docs
```

### 3. Use the Template
The `.gitmessage` template will auto-load. Just follow it:

```
<type>(<scope>): <subject>

[body]

[footer]
```

### 4. Reference Issues
Always link to GitHub issues:

```bash
Closes #42
Fixes #42, #43
Related to #42
```

### 5. Explain WHY
Most important part of a commit message:

```
❌ BAD:
fix: change timeout value

✅ GOOD:
fix(streaming): increase HLS timeout from 2s to 3s

Original 2s timeout was too short for cellular networks.
Increased to 3s after testing on LTE. Fixes buffering
issues without impacting performance on WiFi.

Closes #123
```

---

## 🚀 Commands Reference

```bash
# View last commit
git log -1

# View last 5 commits
git log -5 --oneline

# View commit details
git show <hash>

# Amend last commit
git commit --amend

# See what changed
git diff

# Staged changes
git diff --staged

# Unstage a file
git restore --staged <file>
```

---

## 🎓 Learning Path

1. **First time?** Run `./scripts/commit-help.sh all` to see all patterns
2. **Before each commit:** Run `./scripts/commit-help.sh <type>` 
3. **Need details?** Read `COMMIT_GUIDE.md`
4. **Unsure about format?** The reminder shows on every `git commit`
5. **After a few commits:** It becomes muscle memory!

---

## 📊 Commit Quality Improvement

With these tools:

| Before | After |
|--------|-------|
| Vague: "stuff" | Clear: "feat(playback): add pause button" |
| Mixed changes | One logical change per commit |
| No context | Explains why |
| Hard to debug | Easy to git bisect |
| Lost history | Rich commit history |

---

## 🔄 The Flow

```
1. Make changes
   ↓
2. Run: ./scripts/commit-help.sh <type>
   ↓
3. Run: git commit
   ↓
4. See reminder (auto)
   ↓
5. Fill template (type, scope, subject, body, footer)
   ↓
6. Save and close
   ↓
7. Verify: git log -1
   ↓
8. Push: git push
```

---

## ✅ Checklist Before Pushing

- [ ] Commit message follows format
- [ ] Subject ≤50 characters
- [ ] Imperative mood (add, not added)
- [ ] No period at end
- [ ] Explains WHY not HOW
- [ ] Issue referenced (if applicable)
- [ ] Tests pass
- [ ] One logical change

---

## 🎉 Ready to Commit!

You now have:
1. **Automatic reminders** (every `git commit`)
2. **Quick reference** (`./scripts/commit-help.sh`)
3. **Comprehensive guide** (`COMMIT_GUIDE.md`)
4. **Template** (`.gitmessage`)

**Next commit?**
```bash
./scripts/commit-help.sh <type>  # Check format
git commit                        # Write message
git log -1                        # Verify
git push                          # Done!
```

---

**Last Updated:** 2026-08-10

---
**Last Updated:** 2026-08-10 (1786357473) by amonrit

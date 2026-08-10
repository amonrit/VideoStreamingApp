#!/bin/bash
# Quick reference for commits by scenario

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_feature_commit() {
    echo -e "${GREEN}📋 FEATURE (feat:) COMMIT${NC}"
    echo ""
    echo "Use when: Adding a new feature or capability"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
feat(playback): add pause/resume controls

- Add pause() method to PlaybackViewModel
- Create pause button in VideoPlayerView
- Update debug panel to show current state

Closes #42
EOF
    echo ""
}

show_fix_commit() {
    echo -e "${GREEN}🐛 BUG FIX (fix:) COMMIT${NC}"
    echo ""
    echo "Use when: Fixing a bug or issue"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
fix(streaming): resolve HLS segment timeout

Increase timeout from 2s to 3s to handle slower networks.
This fixes buffering issues on cellular connections.

Fixes #123
EOF
    echo ""
}

show_docs_commit() {
    echo -e "${GREEN}📚 DOCUMENTATION (docs:) COMMIT${NC}"
    echo ""
    echo "Use when: Adding or updating documentation"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
docs: update DEVELOPMENT.md with debugging tips

Add section on using Xcode Console filters.
Includes examples for common debug patterns.
EOF
    echo ""
}

show_refactor_commit() {
    echo -e "${GREEN}♻️ REFACTOR (refactor:) COMMIT${NC}"
    echo ""
    echo "Use when: Refactoring code (no behavior change)"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
refactor(viewmodel): extract observer setup to Worker

Moved setupKVOObservers() from PlaybackViewModel
to VideoPlayerWorker for reusability.

Behavior unchanged, improves code organization.
EOF
    echo ""
}

show_test_commit() {
    echo -e "${GREEN}✅ TEST (test:) COMMIT${NC}"
    echo ""
    echo "Use when: Adding or updating tests"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
test: add PlaybackViewModel pause tests

Add tests for:
- pause() stops playback
- pause() then play() resumes
- pause() while buffering
EOF
    echo ""
}

show_perf_commit() {
    echo -e "${GREEN}⚡ PERFORMANCE (perf:) COMMIT${NC}"
    echo ""
    echo "Use when: Improving performance"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
perf(ui): optimize ContentView rendering

Problem: ContentView re-rendered 200x on state change
Solution: Extract expensive calculation to computed property
Result: Reduce renders to 2-3, improve from 500ms to 50ms

Measured with Xcode Instruments Time Profiler.
EOF
    echo ""
}

show_chore_commit() {
    echo -e "${GREEN}🔧 CHORE (chore:) COMMIT${NC}"
    echo ""
    echo "Use when: Build, dependencies, config changes"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
chore: update Swift formatting in .editorconfig

Ensure consistent 4-space indentation across all editors.
EOF
    echo ""
}

show_style_commit() {
    echo -e "${GREEN}🎨 STYLE (style:) COMMIT${NC}"
    echo ""
    echo "Use when: Formatting changes (no logic change)"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
style: fix indentation in PlaybackViewModel
EOF
    echo ""
}

show_ci_commit() {
    echo -e "${GREEN}🔄 CI (ci:) COMMIT${NC}"
    echo ""
    echo "Use when: CI/CD pipeline changes"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    cat << 'EOF'
ci: add GitHub Actions workflow for testing
EOF
    echo ""
}

show_tips() {
    echo -e "${YELLOW}💡 QUICK TIPS${NC}"
    echo ""
    echo "1. Subject line ≤50 characters"
    echo "2. Imperative mood (add, not added)"
    echo "3. No period at end of subject"
    echo "4. One commit = one logical change"
    echo "5. Explain WHY, not HOW"
    echo "6. Reference issues: Closes #42"
    echo ""
}

show_help() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}      COMMIT GUIDE - Quick Reference${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage: ./scripts/commit-help.sh [scenario]"
    echo ""
    echo "Scenarios:"
    echo "  feature      - Adding a new feature"
    echo "  fix          - Fixing a bug"
    echo "  docs         - Documentation changes"
    echo "  refactor     - Code refactoring"
    echo "  test         - Adding/updating tests"
    echo "  perf         - Performance improvements"
    echo "  chore        - Build/config/dependencies"
    echo "  style        - Formatting changes"
    echo "  ci           - CI/CD changes"
    echo "  tips         - Quick tips"
    echo "  all          - Show all"
    echo ""
    echo "Examples:"
    echo "  ./scripts/commit-help.sh feature"
    echo "  ./scripts/commit-help.sh fix"
    echo "  ./scripts/commit-help.sh all"
    echo ""
}

case "$1" in
    feature|feat)
        show_feature_commit
        ;;
    fix)
        show_fix_commit
        ;;
    docs)
        show_docs_commit
        ;;
    refactor)
        show_refactor_commit
        ;;
    test)
        show_test_commit
        ;;
    perf)
        show_perf_commit
        ;;
    chore)
        show_chore_commit
        ;;
    style)
        show_style_commit
        ;;
    ci)
        show_ci_commit
        ;;
    tips)
        show_tips
        ;;
    all)
        show_feature_commit
        show_fix_commit
        show_docs_commit
        show_refactor_commit
        show_test_commit
        show_perf_commit
        show_chore_commit
        show_style_commit
        show_ci_commit
        show_tips
        ;;
    *)
        show_help
        ;;
esac

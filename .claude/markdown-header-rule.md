Last Modified: 08/10/2026 (1786502400) by amonrit

# Markdown File Header Rule

## Rule: Add Modification Metadata to All .md Files

**Effective Date:** 2026-08-10

### Format

Every `.md` file in this project MUST have the following header on the very first line:

```
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME
```

### Example

```
Last Modified: 08/10/2026 (1786502400) by amonrit

# Document Title

Rest of document content...
```

### Details

- **Placement**: First line of the file (before any other content including titles)
- **Date Format**: MM/DD/YYYY (e.g., 08/10/2026)
- **Unix Timestamp**: Seconds since epoch (e.g., 1786502400 for 2026-08-10)
- **Username**: GitHub username or git user (e.g., amonrit)
- **Spacing**: Blank line after header, then content

### When to Update

Update the header whenever you edit the file:
1. Change the date to current date
2. Update Unix timestamp to current time
3. Keep username as the person making the edit

### Files Affected

Apply to ALL `.md` files in:
- `/steam/` (root level)
- `/steam/.claude/`
- `/steam/.claude/agents/`
- `/steam/.claude/instructions/`
- `/steam/streaming/`
- `/steam/.github/`

### Why?

- Track file modification history
- Identify when documentation was last updated
- Help with version control and documentation maintenance
- Audit trail for regulatory/documentation purposes

### Unix Timestamp Helper

To get current Unix timestamp:
```bash
date +%s
```

Or calculate for a specific date (macOS):
```bash
date -f "%m/%d/%Y" -j "08/10/2026" +%s
```

---

**Approved:** amonrit  
**Status:** Active

---
**Last Updated:** 2026-08-10 (1786357473) by amonrit

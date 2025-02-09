# Visidian Link Notes Documentation

## YAML Frontmatter Handling

### Overview
Visidian handles YAML frontmatter in markdown files for metadata like tags and links. The implementation ensures proper parsing and updating of YAML content without duplication.

### Key Components

#### YAML Parsing
- Uses a real YAML parser if available (`yaml#decode`)
- Falls back to a simple regex-based parser for basic tag and link extraction
- Handles both single values and arrays in YAML format

#### YAML Updates
When updating YAML frontmatter (e.g., when adding links), the process:
1. Preserves the opening `---` marker
2. Keeps all existing YAML fields (title, tags, status, etc.) unchanged
3. Only updates the 'links' field
4. Preserves the closing `---` marker
5. Maintains all non-YAML content exactly as it was

This selective update ensures that other metadata remains intact while only modifying the links section.

### Example YAML Structure
```yaml
---
title: My Project Note
tags: [project, planning]
status: active
created: 2025-01-15
links: [reference.md, task-list.md]  # Only this field is modified
---
```

Note: When adding new links, only the `links` field is modified. All other fields (title, tags, status, etc.) remain unchanged.

### Implementation Details
- Function: `s:update_yaml_frontmatter`
  - Purpose: Updates only the links field in YAML frontmatter
  - Process: Single-pass file processing that preserves all other YAML fields
  - Maintains document structure and all other metadata

### Best Practices
1. Always use the standard YAML frontmatter format with `---` markers
2. Keep YAML content at the top of the file
3. Use consistent formatting for tags and links

# Contributing to Cabriolet Documentation

Thank you for your interest in improving Cabriolet's documentation! This guide will help you make effective contributions.

## Table of Contents

- [Quick Start](#quick-start)
- [Documentation Structure](#documentation-structure)
- [Writing Guidelines](#writing-guidelines)
- [Document Templates](#document-templates)
- [YAML Front Matter](#yaml-front-matter)
- [Cross-Referencing](#cross-referencing)
- [Code Examples](#code-examples)
- [Testing Your Changes](#testing-your-changes)
- [Submitting Changes](#submitting-changes)

## Quick Start

1. **Set up your environment**:
   ```bash
   cd docs
   bundle install
   bundle exec jekyll serve
   ```

2. **Make your changes** to the `.adoc` files

3. **Preview locally** at `http://localhost:4000/cabriolet/`

4. **Run link checker**:
   ```bash
   bundle exec jekyll build
   lychee --config .lychee.toml _site
   ```

5. **Submit a pull request** with a clear description

## Documentation Structure

Our documentation is organized hierarchically:

```
docs/
├── getting-started/     # For new users
├── guides/              # Task-oriented how-to guides
│   ├── basic-usage/
│   ├── compression/
│   ├── formats/
│   └── advanced-usage/
├── reference/           # API and CLI reference
│   ├── api/
│   └── cli/
├── concepts/            # Conceptual explanations
├── architecture/        # Design and implementation
├── developer/           # For contributors
└── appendix/            # Supporting materials
```

### When to Add a New Page vs Update Existing

**Add a new page when**:
- Covering a distinct topic not addressed elsewhere
- Adding documentation for a new feature
- Creating a new guide or tutorial
- The existing page would exceed 500 lines

**Update an existing page when**:
- Clarifying or expanding existing content
- Adding examples to existing features
- Fixing errors or outdated information
- Improving organization of current content

## Writing Guidelines

### Style and Tone

- **Be clear and concise**: Use simple language and short sentences
- **Use active voice**: "Extract the file" not "The file is extracted"
- **Be specific**: Provide concrete examples and code snippets
- **Define technical terms**: Explain jargon on first use
- **Use sentence case**: "Getting started" not "Getting Started"

### Structure

Every documentation page should follow this structure:

1. **Title and front matter** (YAML metadata)
2. **Introduction** (what this page covers)
3. **Main content** (organized with clear headings)
4. **Examples** (practical demonstrations)
5. **Related links** (see also section)

### Formatting Standards

- **Line length**: Wrap at 80 characters (except for links and code)
- **Headings**: Use sentence case, not title case
- **Lists**: Use `*` for unordered, `.` for ordered
- **Code**: Use backticks for inline, source blocks for multi-line
- **Links**: Use descriptive text, not "click here"

## Document Templates

### Tutorial Template

```asciidoc
---
title: Tutorial Name
parent: Parent Section
nav_order: N
---

== Tutorial Name

=== Purpose

Brief description of what the reader will learn.

=== Prerequisites

* Prerequisite 1
* Prerequisite 2

=== Step 1: First Step

Explanation of the first step.

[source,ruby]
----
# Code example
----

=== Step 2: Second Step

Explanation of the second step.

[source,ruby]
----
# Code example
----

=== Summary

What the reader accomplished.

=== Next Steps

* Link to related tutorial
* Link to advanced topic
```

### Reference Template

```asciidoc
---
title: API/CLI Reference Name
parent: Reference
nav_order: N
---

== API/CLI Reference Name

=== Overview

Brief description of the API/CLI feature.

=== Syntax

[source,ruby]
----
ClassName.method_name(param1, param2)
----

=== Parameters

`param1`:: Type - Description
`param2`:: Type - Description

=== Return Value

Description of return value.

=== Examples

.Example 1: Description
[source,ruby]
----
# Example code
----

.Example 2: Description
[source,ruby]
----
# Example code
----

=== Errors

Possible errors and how to handle them.

=== See Also

* <<related/page#,Related Topic>>
```

### Concept Template

```asciidoc
---
title: Concept Name
parent: Concepts
nav_order: N
---

== Concept Name

=== Overview

High-level explanation of the concept.

=== How It Works

Detailed explanation with diagrams if needed.

[source]
----
ASCII diagram or flowchart
----

=== Why It Matters

Practical implications and use cases.

=== Examples

Real-world examples demonstrating the concept.

=== See Also

* <<related/concept#,Related Concept>>
* <<guides/how-to#,Practical Guide>>
```

## YAML Front Matter

Every `.adoc` file must start with YAML front matter:

```yaml
---
title: Page Title
parent: Parent Page Title  # Optional, for navigation hierarchy
nav_order: 5              # Required for proper navigation ordering
has_children: true        # Only for index pages with children
nav_exclude: false        # Set to true to hide from navigation
---
```

### Front Matter Guidelines

**Required fields**:
- `title`: The page title (appears in navigation and as H1)
- `nav_order`: Number controlling position in navigation (lower = earlier)

**Optional fields**:
- `parent`: Links this page under another in navigation
- `has_children`: Set to `true` for index pages with sub-pages
- `nav_exclude`: Set to `true` to hide from navigation menu
- `grand_parent`: For three-level navigation hierarchies

### Navigation Ordering

Use consistent nav_order values:
- `0-9`: Top-level sections (Home, Getting Started, etc.)
- `10-99`: Major subsections
- `100+`: Detailed pages

Example:
```yaml
# Main sections
Home: 0
Getting Started: 1
Guides: 2
Reference: 3

# Guides subsections
Basic Usage: 10
Compression: 20
Formats: 30
Advanced Usage: 40

# Individual pages
Extracting Files: 100
Creating Archives: 101
```

## Cross-Referencing

### Internal Links

Use AsciiDoc cross-reference syntax:

```asciidoc
<<path/to/file#,Link Text>>
<<path/to/file#section-id,Link to Specific Section>>
```

**Examples**:
```asciidoc
See the <<getting-started/installation#,Installation Guide>>.
Learn about <<concepts/compression-algorithms#lzx,LZX compression>>.
```

**Best practices**:
- Use descriptive link text (not "click here")
- Link to specific sections when relevant
- Verify links with the link checker before committing

### External Links

Use standard AsciiDoc link syntax:

```asciidoc
https://example.com[Link Text]
```

**Best practices**:
- Prefer official documentation and authoritative sources
- Include links in a "See Also" or "Resources" section
- Use HTTPS when available

## Code Examples

### Inline Code

Use backticks for short code snippets, commands, and file names:

```asciidoc
Use the `extract` command to extract files.
Edit the `_config.yml` file.
```

### Code Blocks

Use AsciiDoc source blocks with language specification:

```asciidoc
[source,ruby]
----
require 'cabriolet'

decompressor = Cabriolet::CAB::Decompressor.new('archive.cab')
decompressor.extract('output/')
----
```

**Supported languages**:
- `ruby` - Ruby code
- `bash` or `shell` - Shell commands
- `yaml` - YAML configuration
- `json` - JSON data
- `asciidoc` - AsciiDoc markup
- `console` - Terminal output

### Example Blocks

For complete examples with titles:

```asciidoc
.Extracting specific files
[example]
====
[source,ruby]
----
decompressor = Cabriolet::CAB::Decompressor.new('archive.cab')
decompressor.extract_file('readme.txt', 'output/readme.txt')
----

This extracts only the `readme.txt` file to the specified location.
====
```

### Code Best Practices

1. **Keep examples simple** - Focus on the concept being taught
2. **Make them runnable** - Provide complete, working examples
3. **Add comments** - Explain non-obvious code
4. **Show output** - Include expected results when helpful
5. **Handle errors** - Show proper error handling when relevant

## Testing Your Changes

Before submitting, test your changes:

### 1. Build Locally

```bash
cd docs
bundle exec jekyll serve
```

Visit `http://localhost:4000/cabriolet/` to review.

### 2. Check for Build Errors

Ensure Jekyll builds without errors:

```bash
bundle exec jekyll build --trace
```

### 3. Validate Links

Run the link checker:

```bash
lychee --config .lychee.toml _site
```

Fix any broken links before submitting.

### 4. Visual Review

Check your changes in the browser:
- [ ] Page renders correctly
- [ ] Navigation links work
- [ ] Code examples display properly
- [ ] Cross-references resolve
- [ ] Formatting is consistent
- [ ] Images (if any) load correctly

### 5. Mobile View

Test responsive design on mobile:
- [ ] Text is readable
- [ ] Navigation works
- [ ] Code blocks don't overflow

### 6. Accessibility

Check basic accessibility:
- [ ] Headings follow logical hierarchy
- [ ] Links have descriptive text
- [ ] Code has language specification
- [ ] Images have alt text (if applicable)

## Submitting Changes

### Commit Messages

Use semantic commit messages:

```
docs(section): brief description

Longer explanation if needed.

Fixes #123
```

**Types**:
- `docs`: Documentation changes
- `fix`: Fix documentation errors
- `style`: Formatting changes only

**Examples**:
```
docs(installation): add macOS-specific instructions
docs(api): clarify extract method parameters
fix(guides): correct broken link to compression guide
style(reference): improve code formatting
```

### Pull Request Guidelines

1. **Create a focused PR** - One topic per pull request
2. **Write a clear description**:
   - What changes were made
   - Why they were needed
   - What was tested
3. **Reference issues** - Link to related issues
4. **Request review** - Ask for feedback from maintainers

**PR Template**:
```markdown
## Description
Brief description of changes

## Motivation
Why this change is needed

## Changes
- Added new page for X
- Updated examples in Y
- Fixed broken links in Z

## Testing
- [ ] Built locally without errors
- [ ] Verified all links work
- [ ] Checked mobile responsiveness
- [ ] Reviewed in browser

## Screenshots
If applicable, add screenshots

Fixes #(issue number)
```

### Review Process

Documentation changes go through:

1. **Automated checks** - CI/CD runs build, link check, validation
2. **Maintainer review** - Technical accuracy and style review
3. **Community feedback** - Input from other contributors
4. **Merge** - After approval, changes are merged

## Common Tasks

### Adding a New Guide

1. Create file in appropriate directory
2. Add YAML front matter
3. Write content using guide template
4. Add to parent index page
5. Test locally
6. Submit PR

### Updating API Documentation

1. Verify changes match code implementation
2. Update parameter descriptions
3. Add/update code examples
4. Test examples work
5. Update related pages if needed

### Fixing Broken Links

1. Run link checker to identify issues
2. Update or remove broken links
3. Verify fixes with link checker
4. Submit PR with fixes

## Getting Help

- **Questions**: Open a discussion on GitHub
- **Issues**: Report documentation problems
- **Chat**: Join our community chat (if available)
- **Email**: Contact maintainers directly

## License

By contributing to this documentation, you agree that your contributions will be licensed under the same license as Cabriolet.

Thank you for helping improve Cabriolet's documentation!
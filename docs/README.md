# Cabriolet Documentation

This directory contains the complete documentation for Cabriolet, built with Jekyll and the Just the Docs theme.

## Building the Documentation Locally

### Prerequisites

- Ruby 2.7 or higher
- Bundler (`gem install bundler`)

### Setup

1. Navigate to the docs directory:
   ```bash
   cd docs
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Build and serve the documentation:
   ```bash
   bundle exec jekyll serve
   ```

4. Open your browser to `http://localhost:4000/cabriolet/`

### Building for Production

To build static HTML files:

```bash
bundle exec jekyll build
```

The output will be in the `_site` directory.

## Documentation Structure

The documentation is organized into the following sections:

```
docs/
├── index.adoc                    # Home page
├── getting-started/              # Installation and quick start
│   ├── index.adoc
│   ├── installation.adoc
│   ├── quick-start.adoc
│   └── your-first-cab.adoc
├── guides/                       # Comprehensive usage guides
│   ├── basic-usage/              # Common operations
│   ├── compression/              # Compression algorithms
│   ├── formats/                  # File format guides
│   └── advanced-usage/           # Advanced features
├── reference/                    # Technical reference
│   ├── cli/                      # Command-line interface
│   └── api/                      # Ruby API
├── concepts/                     # Core concepts explained
├── architecture/                 # Design and architecture
├── developer/                    # Contributing and development
└── appendix/                     # Additional resources
```

## Contributing to Documentation

We welcome contributions to improve the documentation! See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Quick Contribution Steps

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/cabriolet.git
   cd cabriolet
   ```

3. **Create a feature branch**:
   ```bash
   git checkout -b docs/improve-installation-guide
   ```

4. **Make your changes** to the documentation files

5. **Test locally**:
   ```bash
   cd docs
   bundle install
   bundle exec jekyll serve
   ```

   Visit `http://localhost:4000/cabriolet/` to verify your changes

6. **Run link checker** (optional but recommended):
   ```bash
   bundle exec jekyll build
   lychee --config .lychee.toml _site
   ```

7. **Commit your changes**:
   ```bash
   git add .
   git commit -m "docs: improve installation guide"
   ```

8. **Push to your fork**:
   ```bash
   git push origin docs/improve-installation-guide
   ```

9. **Create a pull request** on GitHub

## Common Documentation Tasks

### Adding a New Page

1. Create a new `.adoc` file in the appropriate directory
2. Add YAML front matter at the top:
   ```yaml
   ---
   title: Your Page Title
   parent: Parent Page Title
   nav_order: 5
   ---
   ```
3. Write your content in AsciiDoc format
4. Test locally to ensure proper rendering and navigation

### Updating Navigation

Navigation is controlled by YAML front matter in each file:

- `nav_order`: Controls position in navigation (lower numbers appear first)
- `parent`: Links to parent page in navigation hierarchy
- `has_children`: Set to `true` for index pages with child pages
- `nav_exclude`: Set to `true` to hide from navigation

### Cross-Referencing Pages

Use AsciiDoc cross-reference syntax:

```asciidoc
<<path/to/file#,Link Text>>
<<path/to/file#anchor,Link to Section>>
```

Examples:
```asciidoc
See the <<getting-started/installation#,Installation Guide>> for details.
Learn about <<concepts/compression-algorithms#lzx,LZX compression>>.
```

### Adding Code Examples

Use AsciiDoc source blocks with language specification:

```asciidoc
[source,ruby]
----
require 'cabriolet'

decompressor = Cabriolet::CAB::Decompressor.new('archive.cab')
decompressor.extract('output/')
----
```

### Adding Tables

Use AsciiDoc table syntax:

```asciidoc
[cols="1,2,3"]
|===
|Column 1 |Column 2 |Column 3

|Cell 1
|Cell 2
|Cell 3
|===
```

### Adding Admonitions

Use AsciiDoc admonition blocks:

```asciidoc
NOTE: This is a note to highlight important information.

WARNING: This warns about potential issues.

TIP: This provides helpful tips.

IMPORTANT: This marks critical information.

CAUTION: This warns about dangerous operations.
```

## Link Validation

We use [lychee](https://github.com/lycheeverse/lychee) to validate all links in the documentation.

### Running Link Checker Locally

1. Install lychee (see [installation guide](https://github.com/lycheeverse/lychee#installation))

2. Build the site:
   ```bash
   bundle exec jekyll build
   ```

3. Run the link checker:
   ```bash
   lychee --config .lychee.toml _site
   ```

### Understanding Link Check Results

The link checker will report:
- **Broken links** (404 errors): Must be fixed
- **Timeout errors**: May need to retry or update configuration
- **Excluded links**: Intentionally skipped (configured in `.lychee.toml`)

### Fixing Broken Links

1. Review the error report from lychee
2. Fix the broken links in the source `.adoc` files
3. Re-build and re-test
4. Commit the fixes

## Documentation Standards

### File Naming

- Use lowercase with hyphens: `my-new-page.adoc`
- Use descriptive names: `lzx-compression.adoc` not `lzx.adoc`
- Index pages: always named `index.adoc`

### Headings

- Use sentence case: "Getting started with Cabriolet"
- Not title case: "Getting Started With Cabriolet"
- Keep headings concise and descriptive

### Writing Style

- Use active voice: "Extract the file" not "The file is extracted"
- Be concise and clear
- Use examples to illustrate concepts
- Define technical terms on first use
- Link to related documentation

### Code Formatting

- Inline code: Use backticks for commands, file names, code elements
- Code blocks: Use AsciiDoc source blocks with language specification
- Command output: Use source blocks without language or with `console`
- File paths: Use inline code formatting

## Testing Your Changes

Before submitting a pull request:

1. **Build locally**: Ensure no Jekyll build errors
2. **Visual check**: Review your pages in the browser
3. **Navigation**: Verify navigation links work correctly
4. **Cross-references**: Check all internal links
5. **Code examples**: Test that code examples work
6. **Link validation**: Run lychee to check for broken links
7. **Mobile view**: Check responsive design on mobile

## Getting Help

- **Documentation issues**: Open an issue with the `documentation` label
- **Build problems**: Check Jekyll's [documentation](https://jekyllrb.com/docs/)
- **AsciiDoc syntax**: See [AsciiDoc Writer's Guide](https://asciidoctor.org/docs/asciidoc-writers-guide/)
- **Theme issues**: Check [Just the Docs documentation](https://just-the-docs.github.io/just-the-docs/)

## Continuous Integration

Documentation is automatically built and validated on every push to the repository:

- **Jekyll build**: Ensures documentation builds successfully
- **Link checking**: Validates all internal and external links
- **Pull request previews**: Automated builds for all pull requests

See [`.github/workflows/docs.yml`](../.github/workflows/docs.yml) for CI configuration.

## License

The documentation is licensed under the same license as Cabriolet itself. See [LICENSE](../LICENSE) for details.
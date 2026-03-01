# PDF Generation (md2pdf)

**Script:** `md2pdf` (symlinked to `~/.local/bin/`, source at `scripts/md2pdf.sh`)

## Usage

```bash
md2pdf input.md              # → input.pdf (same name, .pdf extension)
md2pdf input.md output.pdf   # → explicit output path
```

**Under the hood:** `pandoc` + `tectonic` (both installed via Homebrew). Single command, no intermediate HTML step. Uses Avenir Next (body) + Menlo (code), 1in margins, 11pt.

## Gotchas

- Avenir Next doesn't have arrow (→) or emoji glyphs — warnings only, PDF still generates. Avoid these characters in content that needs to render perfectly.
- First run in a new directory may be slow (tectonic downloads LaTeX packages and caches them).

**This is the standard way to generate PDFs.** Don't use Chrome headless, wkhtmltopdf, or browser-based PDF generation for Markdown conversion.

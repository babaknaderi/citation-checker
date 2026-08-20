# Citation Checker

An AI agent that detects **citation hallucinations** in LaTeX papers — fabricated sources, incorrect bibliographic metadata, and misattributed claims.

## The Problem

AI writing assistants can generate plausible-looking but **completely fabricated** references. Even human-written papers sometimes contain:
- Citations to papers that do not exist
- Claims attributed to the wrong source
- Metadata errors (wrong year, venue, or authors)
- Misrepresented findings from cited work

Catching these errors manually is tedious: each reference requires searching databases, reading the full paper, and cross-checking claims. This agent automates that process.

## What It Does

The agent performs a **two-pass verification** on every `\cite{}` in your LaTeX paper:

| Pass | What it checks | Example finding |
|------|---------------|-----------------|
| **Pass 1: Existence** | Does this paper actually exist? Do the metadata (title, authors, year, venue) match? | "Reference `smith2024deep` not found in any trusted source after multiple searches" |
| **Pass 2: Claim Alignment** | Does the cited paper actually say what you claim it says? | "Paper claims 'Smith et al. proposed method X' but Smith's paper describes method Y" |

### Key Features

- **Incremental verification** — maintains a JSON ledger so unchanged references are skipped on re-runs, saving time during the write–review cycle
- **Severity classification** — findings are rated CRITICAL, MAJOR, NEEDS REVIEW, MINOR, or VERIFIED with confidence levels
- **Conservative by design** — prefers NEEDS REVIEW over false accusations of hallucination
- **Installable and updateable** — distributed as a plugin for GitHub Copilot CLI and Claude Code
- **Single maintained profile** — both hosts load the canonical definition from `agents/citation-checker.agent.md`

## Quick Start

Install the plugin once. You do not need to copy the agent definition into each project.

### GitHub Copilot CLI

```shell
copilot plugin marketplace add babaknaderi/citation-checker
copilot plugin install citation-checker@citation-checker
```

Update later with:

```shell
copilot plugin update citation-checker
```

### Claude Code

```text
/plugin marketplace add babaknaderi/citation-checker
/plugin install citation-checker@citation-checker
```

Update later with:

```text
/plugin marketplace update citation-checker
/plugin update citation-checker@citation-checker
```

### Run the agent

**GitHub Copilot CLI:**

Activate the installed agent before requesting an audit:

```
/agent citation-checker:citation-checker
```

Then request the audit:

```
Check the paper in this directory.
```

Alternatively, select it when starting Copilot:

```powershell
copilot --agent citation-checker:citation-checker
```

Explicit selection is recommended. If the default Copilot agent merely delegates an audit based on a natural-language mention, it can impose read-only constraints that prevent Citation Checker from updating `.citation-checker/ledger.json`.

Plugin agents are namespaced as `<plugin>:<agent>`, so both GitHub Copilot CLI and Claude Code expose this agent as `citation-checker:citation-checker`.

**Claude Code:** ask Claude to use `citation-checker:citation-checker`, or mention that scoped agent explicitly.

```
Run the citation-checker agent on this paper.
```

### Review the output

The agent produces a structured report with one block per citation:

```
[REF: smith2024deep — citation 1 of 1]
- Result: ✗ ACTION REQUIRED
- Existence: CRITICAL
- Title: Deep Learning for Video Quality Assessment
- Claim in paper: "Smith et al. proposed a transformer-based VQA model"
- Citation role: Direct attribution
- What I accessed: Searched Semantic Scholar, DBLP, Google Scholar
- Finding: Paper not found in any trusted source. Likely fabricated.
- Severity: CRITICAL
- Confidence: HIGH
- Evidence: No results on any database

[REF: jones2023video — citation 1 of 1]
- Result: ✗ ACTION REQUIRED
- Existence: VERIFIED
- Title: Video Compression with Learned Representations
- Claim in paper: "Jones et al. achieve 38.2 dB PSNR on Vimeo-90K"
- Citation role: Evidence/performance
- What I accessed: Full text via arXiv HTML (arXiv:2303.12345)
- Finding: Paper reports 36.1 dB PSNR on Vimeo-90K, not 38.2 dB
- Severity: MAJOR
- Confidence: HIGH
- Evidence: https://arxiv.org/html/2303.12345 — Table 2, row 3
```

And a summary:

```
## Summary
- Total references checked: 42, citation instances: 58
- ✓ ALL GOOD: 54
- ✗ ACTION REQUIRED: 4
- CRITICAL: 1 (fabricated reference)
- MAJOR: 1 (wrong performance number)
- NEEDS REVIEW: 2 (could not access paper content)
```

## How It Works

### Project Discovery

The host applies relevant project instructions before the agent starts. Citation Checker then:
1. Finds `.tex` files inside the invocation directory
2. Follows LaTeX include and bibliography directives
3. Falls back to `.bib` discovery inside that directory when the paper does not declare its bibliography

It does not search parent directories, repository documentation, fixtures, or instruction files as citation evidence.

### Incremental Ledger

The agent maintains a verification ledger at `.citation-checker/ledger.json`. This generated runtime state is ignored by Git. On each run:
- **Unchanged** references (same BibTeX metadata, same claim text) are **skipped**
- **Modified** references are re-verified (only the changed parts)
- **New** references get full verification
- **Removed** references are dropped from the ledger

This makes re-runs fast during iterative paper writing.

### Trusted Source Hierarchy

The agent prioritizes evidence from authoritative sources:
1. **DOI resolver / Crossref / publisher pages** (strongest)
2. **arXiv, OpenReview, conference proceedings**
3. **DBLP, Semantic Scholar, Google Scholar**
4. **General web pages** (weakest — supporting signal only)

### Severity Levels

| Severity | Meaning |
|----------|---------|
| **CRITICAL** | Reference likely does not exist, or a claim is clearly contradicted by the cited paper |
| **MAJOR** | Key metadata mismatch (wrong year/venue/authors), or an evidence claim cannot be corroborated with reason for doubt |
| **NEEDS REVIEW** | Cannot confirm or refute — requires human judgment |
| **MINOR** | Minor metadata discrepancy (abbreviation difference, missing page numbers) |
| **VERIFIED** | Reference confirmed to exist and claims are consistent |

Reports show `✓ ALL GOOD` only when both existence and claim alignment are verified. Any item requiring correction or human review is marked `✗ ACTION REQUIRED`.

## Handling Findings

After the agent reports findings, address them based on severity:

### CRITICAL (reference does not exist)
Remove the citation and the claim that depends on it. If the claim is essential, search for a real paper that supports it, add the correct BibTeX entry, and update the `\cite{}`.

### CRITICAL (claim contradicted)
Rewrite the claim to accurately reflect what the cited paper says. If the claim cannot be made accurate, remove it.

### MAJOR (metadata mismatch)
Correct the BibTeX entry to match the real publication metadata (title, year, authors, venue).

### MAJOR (claim unverifiable with doubt)
Add hedging language ("appears to", "has been reported to") or find a more appropriate citation.

### NEEDS REVIEW
Do not auto-fix. These require human judgment — read the cited paper yourself to verify.

### MINOR
Fix metadata if straightforward (e.g., add missing page numbers). Otherwise, ignore.

## Try It Out

The [`examples/`](examples/) directory contains a minimal LaTeX project with three references and four citation occurrences.

### Example citations

| Key | Type | What the agent should find |
|-----|------|---------------------------|
| `naderi_vcd_2024` | Real paper, correct codec claim | **✓ VERIFIED** — Crossref confirms the ICASSP publication and the arXiv PDF confirms the QP ranges |
| `zhang_neural_2023` | Fabricated paper | **✗ CRITICAL** — the publication is not found in trusted scholarly records |
| `naderi_vcd_2024` (stratification) | Real paper, misattributed method | **✗ MAJOR** — the VCD paper uses four quality brackets and four SI/TI regions, not the claimed 12-stratum construction |
| `itu-t_recommendation_p910_subjective_2023` | Real standard, scoped claim | **✓ VERIFIED** — the 2023 recommendation defines SI/TI computation, but not the surrounding bins or strata |

### Running the example

1. Install the plugin using the instructions above.

2. Open the `examples/` directory and invoke the agent:

   ```
   Run the citation-checker agent on this paper.
   ```

3. The agent will produce a report similar to:

   ```
   [REF: naderi_vcd_2024 — citation 1 of 2]
   - Result: ✓ ALL GOOD
   - Existence: VERIFIED
   - Title: VCD: A Video Conferencing Dataset for Video Compression
   - Claim in paper: "We follow the codec benchmarking methodology of Naderi et al.,
     encoding each source clip at five QP levels"
   - Citation role: Direct attribution
   - What I accessed: Crossref metadata and full text extracted from arXiv PDF
   - Finding: Claim confirmed — H.264/H.265 use five QPs from 20–44 and H.266
     uses five QPs from 22–42
   - Severity: VERIFIED
   - Confidence: HIGH
   - Evidence: https://doi.org/10.1109/ICASSP48485.2024.10448484;
     https://arxiv.org/pdf/2309.07376

   [REF: naderi_vcd_2024 — citation 2 of 2]
   - Result: ✗ ACTION REQUIRED
   - Existence: VERIFIED
   - Title: VCD: A Video Conferencing Dataset for Video Compression
   - Claim in paper: "The subset selection employs a stratified sampling algorithm
     following Naderi et al."
   - Citation role: Direct attribution
   - What I accessed: Full text extracted from arXiv PDF
   - Finding: The VCD paper does not describe 3 MOS bins × 4 median-split SI/TI
     quadrants. It uses four quality brackets and four SI/TI regions with target
     marginal distributions, so the claimed 12-stratum method is misattributed.
   - Severity: MAJOR
   - Confidence: HIGH
   - Evidence: https://arxiv.org/pdf/2309.07376 — Section 3.1

   [REF: zhang_neural_2023 — citation 1 of 1]
   - Result: ✗ ACTION REQUIRED
   - Existence: CRITICAL
   - Title: Neural Video Codec with Three-Objective Rate-Distortion-Perceptual
     Loss Balancing
   - Claim in paper: "Zhang et al. proposed a neural codec that jointly optimizes
     rate, distortion, and perceptual quality"
   - Citation role: Direct attribution
   - What I accessed: Crossref exact-title query and independent metadata searches
   - Finding: Publication not found in trusted scholarly records
   - Severity: CRITICAL
   - Confidence: HIGH
   - Evidence: No results for title, authors, or venue

   [REF: itu-t_recommendation_p910_subjective_2023 — citation 1 of 1]
   - Result: ✓ ALL GOOD
   - Existence: VERIFIED
   - Title: Subjective video quality assessment methods for multimedia applications
   - Claim in paper: "SI and TI, computed per ITU-T P.910"
   - Citation role: Direct attribution
   - What I accessed: Official October 2023 ITU-T record and technical contents
   - Finding: Claim confirmed for SI/TI computation only; P.910 does not support
     the surrounding median splits, MOS bins, or 12-stratum design
   - Severity: VERIFIED
   - Confidence: HIGH
   - Evidence: https://www.itu.int/rec/T-REC-P.910

   ## Summary
   - Total references checked: 3, citation instances: 4
   - ✓ ALL GOOD: 2 (naderi_vcd_2024 codec claim, ITU-T P.910)
   - ✗ ACTION REQUIRED: 2
   - CRITICAL: 1 (zhang_neural_2023 — fabricated)
   - MAJOR: 1 (naderi_vcd_2024 — misattributed stratification)
   ```

> **Note:** Exact wording varies by model and web search results. The severity
> classifications and key findings should be consistent across runs.

## Requirements

- An AI agent host that supports custom agents like:
	- [GitHub Copilot CLI](https://docs.github.com/en/copilot/copilot-cli)
	- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Plugin support in the selected host
- The agent host must have **web search capability** (the agent uses web search to verify references)
- A LaTeX project with `.tex` and `.bib` files

## Limitations

- **Full-text access varies** — the agent fetches open-access HTML first. For arXiv papers whose HTML exposes only a partial document, it can use an already-installed `pdftotext` executable to extract the PDF under strict timeout, size, output, and cleanup limits. If primary text remains unavailable, the result is NEEDS REVIEW.
- **Web search dependent** — verification quality depends on the agent host's web search and web fetch capabilities.
- **LaTeX only** — supports common natbib and biblatex citation commands in `.tex` files. It does not support Word, Markdown, or other manuscript formats.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on improving the agent.

## License

MIT — see [LICENSE](LICENSE).

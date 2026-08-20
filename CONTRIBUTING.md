# Contributing

Contributions to improve Citation Checker are welcome. This guide explains how to contribute effectively.

## Ways to Contribute

- **Improve the agent definition** — better prompts, edge case handling, or verification strategies
- **Add documentation** — usage examples, platform-specific guides, or troubleshooting tips
- **Report issues** — false positives, false negatives, or platform compatibility problems
- **Share test cases** — example papers (or synthetic snippets) that exercise specific verification scenarios

## Modifying the Agent Definition

The canonical agent profile is `agents/citation-checker.agent.md`. Both supported hosts load this file from the plugin; do not add platform-specific copies.

1. **Test your changes** on a real LaTeX paper with known good and bad references.
2. **Preserve the two-pass structure** (existence check, then claim alignment). This separation is intentional.
3. **Keep the ledger format stable** — changes to the JSON schema should be backward-compatible.
4. **Be conservative** — the agent should prefer NEEDS REVIEW over false CRITICAL findings. Err on the side of caution.

## Testing

There is no automated test suite (the agent runs via an AI host). To test manually:

1. Run `pwsh ./scripts/validate.ps1` to validate the manifests and repository layout.
2. Start the host with the repository loaded directly as a development plugin:
	- GitHub Copilot CLI: `copilot --plugin-dir .`
	- Claude Code: `claude --plugin-dir .`
3. Run it on a LaTeX paper where you know the ground truth.
4. Verify that:
	- All real references are marked VERIFIED
	- Fabricated references are flagged CRITICAL
	- Misattributed claims are flagged appropriately
	- The ledger is written correctly and incremental runs skip unchanged entries

## Pull Request Guidelines

- One logical change per PR
- Describe what you changed and why in the PR description
- Include before/after examples if you changed the agent's behavior
- If you changed the ledger schema, note the backward-compatibility impact

## Releasing

1. Bump the semantic version in `plugin.json` and `.claude-plugin/plugin.json`.
2. Validate both plugin manifests and the marketplace.
3. Test installation in GitHub Copilot CLI and Claude Code.
4. Tag the release with the same version.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

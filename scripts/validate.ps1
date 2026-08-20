$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$rootManifestPath = Join-Path $root "plugin.json"
$claudeManifestPath = Join-Path $root ".claude-plugin/plugin.json"
$marketplacePath = Join-Path $root ".claude-plugin/marketplace.json"
$agentPath = Join-Path $root "agents/citation-checker.agent.md"

$rootManifest = [IO.File]::ReadAllText($rootManifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$claudeManifest = [IO.File]::ReadAllText($claudeManifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$marketplace = [IO.File]::ReadAllText($marketplacePath, [Text.Encoding]::UTF8) | ConvertFrom-Json

if ($rootManifest.name -ne $claudeManifest.name) {
    throw "Plugin names differ between manifests."
}

if ($rootManifest.version -ne $claudeManifest.version) {
    throw "Plugin versions differ between manifests."
}

if ($rootManifest.agents -ne "agents/") {
    throw "Copilot manifest must expose the canonical agents directory."
}

$entry = $marketplace.plugins | Where-Object { $_.name -eq $rootManifest.name }
if ($null -eq $entry -or @($entry).Count -ne 1) {
    throw "Marketplace must contain exactly one entry for '$($rootManifest.name)'."
}

if ($entry.source -ne "./") {
    throw "Marketplace plugin source must reference the repository root."
}

if (-not (Test-Path $agentPath -PathType Leaf)) {
    throw "Canonical agent profile is missing."
}

$agent = [IO.File]::ReadAllText($agentPath, [Text.Encoding]::UTF8)
if ($agent -notmatch '(?s)^---\r?\nname:\s*citation-checker\r?\ndescription:\s*.+?\r?\ntools:\s*\["view", "glob", "rg", "apply_patch", "powershell", "web_fetch", "web_search", "Read", "Write", "Edit", "Bash", "Glob", "Grep", "WebFetch", "WebSearch"\]\r?\n---\r?\n') {
    throw "Agent frontmatter must contain the expected name, description, and restricted tool list."
}

if ($agent -notmatch [regex]::Escape(".citation-checker/ledger.json")) {
    throw "Agent must use the Citation Checker runtime ledger path."
}

if ($agent -notmatch [regex]::Escape("opening that exact path directly")) {
    throw "Agent must require direct hidden-ledger reads instead of glob discovery."
}

if ($agent -notmatch [regex]::Escape("https://arxiv.org/html/<id>") -or
    $agent -notmatch [regex]::Escape("https://ar5iv.labs.arxiv.org/html/<id>")) {
    throw "Agent must require primary full-text retrieval for arXiv papers."
}

if ($agent -notmatch [regex]::Escape("they cannot replace the cited paper")) {
    throw "Agent must not substitute project or repository pages for the cited publication."
}

if ($agent -notmatch [regex]::Escape('Do not search for or read `AGENTS.md`')) {
    throw "Agent must rely on host-applied instructions instead of searching for instruction files."
}

if ($agent -notmatch [regex]::Escape('provides a next `start_index`')) {
    throw "Agent must continue explicitly truncated web responses using start_index."
}

if ($agent -notmatch [regex]::Escape("MUST NOT trigger Crossref, DOI, DBLP")) {
    throw "Claim-only incremental checks must not repeat bibliographic verification."
}

if ($agent -notmatch [regex]::Escape("until the ledger write succeeds")) {
    throw "Agent must persist and verify the ledger before reporting success."
}

if ($agent -notmatch [regex]::Escape("web-search response is a discovery aid and synthesis")) {
    throw "Agent must not treat synthesized web-search answers as authoritative metadata."
}

if ($agent -notmatch [regex]::Escape("Treat quotations produced by native web search as unverified leads")) {
    throw "Agent must verify synthesized quotations against directly retrieved primary content."
}

if ($agent -notmatch [regex]::Escape("prefer the publisher, DOI/Crossref, and final proceedings record")) {
    throw "Agent must resolve metadata conflicts against the cited publication version."
}

if ($agent -notmatch [regex]::Escape("Blocking author-conflict procedure")) {
    throw "Agent must block author findings until the published record is checked directly."
}

if ($agent -notmatch [regex]::Escape("Conference or journal work without a DOI")) {
    throw "Agent must route unidentified published works to Crossref before web search."
}

if ($agent -notmatch [regex]::Escape("If the publisher or Crossref record matches the BibTeX")) {
    throw "Agent must suppress preprint-only author findings when published metadata matches."
}

if ($agent -notmatch [regex]::Escape("Do not use a global numeric request budget")) {
    throw "Agent must not let global request counts suppress mandatory evidence retrieval."
}

$mandatoryArxivOrder = "arXiv papers $([char]0x2014) mandatory order"
if ($agent -notmatch [regex]::Escape($mandatoryArxivOrder)) {
    throw "Agent must use the ordered arXiv HTML-to-PDF retrieval path."
}

if ($agent -notmatch [regex]::Escape("Immediately use the bounded PDF-to-text fallback")) {
    throw "Partial arXiv HTML must trigger PDF extraction before claim-level web search."
}

if ($agent -notmatch [regex]::Escape('Do not conclude `NEEDS REVIEW` until')) {
    throw "Agent must not stop before attempting applicable PDF extraction."
}

if ($agent -notmatch [regex]::Escape("PDF-to-text last resort")) {
    throw "Agent must use a bounded local PDF extraction fallback for inaccessible arXiv sections."
}

if ($agent -notmatch [regex]::Escape("25 MB maximum download")) {
    throw "Agent PDF fallback must enforce a download-size bound."
}

if ($agent -notmatch [regex]::Escape("Split compound sentences into atomic claims")) {
    throw "Agent must scope citations to the atomic claims they grammatically support."
}

if ($agent -notmatch [regex]::Escape('Do not downgrade them to `NEEDS REVIEW`')) {
    throw "Agent must propagate critical reference failures to direct claim alignment."
}

$resultIndicator = "Result: $([char]0x2713) ALL GOOD | $([char]0x2717) ACTION REQUIRED"
if ($agent -notmatch [regex]::Escape($resultIndicator)) {
    throw "Agent report must visibly distinguish clean and actionable citation results."
}

if ($agent -match [regex]::Escape("data/reference_verification_ledger.json")) {
    throw "Agent still references the legacy ledger path."
}

$legacyPaths = @(
    (Join-Path $root ".github/agents/citation-checker.agent.md"),
    (Join-Path $root ".claude/agents/citation-checker.agent.md"),
    (Join-Path $root ".github/agents/reference-checker.agent.md"),
    (Join-Path $root ".claude/agents/reference-checker.agent.md")
)

foreach ($legacyPath in $legacyPaths) {
    if (Test-Path $legacyPath) {
        throw "Legacy duplicate agent profile exists: $legacyPath"
    }
}

Write-Host "Repository validation passed."

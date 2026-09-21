# fix-type-sizes.ps1 — Correct the paragraph size regression and tighten the measure.
#
# WHAT WAS WRONG: applying the modular scale put body paragraphs at 15.68px, which is
# (a) smaller than the 17px it was before and (b) under the 16px comfortable-reading
# floor. Headings shrank too. The scale should size HEADINGS around a fixed readable
# body size, not shrink the body.
#
# Also: 38rem = 608px = ~74 characters at this size, the top of the 65-75 rule.
# 36rem = 576px = ~70 characters, the middle of the range.

$root = "C:\dsh-temp\aaronstalberg-site"

# new scale: body is the anchor at 17px and never scales down
$oldScale = @'
  --t-xs: .78rem; --t-sm: .88rem; --t-base: 1.0625rem; --t-lg: 1.33rem;
  --t-xl: 1.66rem; --t-2xl: 2.07rem; --t-3xl: 2.6rem;
'@
$newScale = @'
  /* body is the anchor and never scales below it */
  --t-xs: .78rem; --t-sm: .9rem; --t-base: 1.0625rem; --t-lg: 1.125rem;
  --t-xl: 1.3rem; --t-2xl: 1.9rem; --t-3xl: 2.4rem;
'@

$pages = @('index.html','about.html','answers.html','profile.html','writing.html','giving.html',
           'writing\ai-search-visibility.html','writing\when-ai-gets-you-wrong.html','writing\ai-automation-failure.html')

foreach ($rel in $pages) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { continue }
  $t = [System.IO.File]::ReadAllText($p)

  $t = $t.Replace($oldScale, $newScale)

  # tighten the measure to the middle of the 65-75 character rule
  $t = $t.Replace('--measure:38rem;', '--measure:36rem;')

  # make sure paragraphs sit at the anchor size, not below it
  if ($t -notmatch 'main p\{font-size') {
    $t = $t.Replace('</style>', "`n  main p{font-size:var(--t-base)}`n  main .lead{font-size:var(--t-lg)}`n</style>")
  }

  [System.IO.File]::WriteAllText($p, $t)
  "sized: $rel"
}
""
"=== verify ==="
$t = [System.IO.File]::ReadAllText("$root\index.html")
"  measure now : " + ([regex]::Match($t,'--measure:([^;]+);').Groups[1].Value)
"  body anchor : " + ([regex]::Match($t,'--t-base:([^;]+);').Groups[1].Value)
"  main p rule : " + ($t -match 'main p\{font-size')

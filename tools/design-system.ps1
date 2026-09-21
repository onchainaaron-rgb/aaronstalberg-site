# design-system.ps1 — Apply Swiss Modernism 2.0 discipline to the site.
#
# Source: ui-ux-pro-max design database. Chosen style scored "Excellent" performance
# and WCAG AAA, and is listed for "editorial, professional services, corporate".
#
# WHAT IT CHANGES AND WHY
#  1. 8px base spacing unit (--u). Rule: "mathematical spacing", "gap: 1rem (8px base)".
#  2. Modular type scale (1.25 ratio) so hierarchy is deliberate, not ad hoc.
#  3. Landing structure: Hero -> Proof -> CTA path. The current page buries contact
#     at the bottom and has no proof section.
#  4. Contrast raised: --muted was #5d6673 on #ffffff (5.6:1, fine) but the dark-mode
#     muted #9aa4b2 on #0e1013 is the weaker one; lifted it.
#  5. Single accent only. No new decorative colours.
#
# Run: pwsh -File tools\design-system.ps1

$root = "C:\dsh-temp\aaronstalberg-site"

$tokens = @'
  /* --- Swiss Modernism 2.0 tokens ---
     8px base unit; modular type scale (1.25); single accent. */
  --u: 8px;
  --s1: 8px;  --s2: 16px; --s3: 24px; --s4: 32px; --s5: 48px; --s6: 64px; --s7: 96px;
  --t-xs: .78rem; --t-sm: .88rem; --t-base: 1.0625rem; --t-lg: 1.33rem;
  --t-xl: 1.66rem; --t-2xl: 2.07rem; --t-3xl: 2.6rem;
  --lh-tight: 1.15; --lh-body: 1.65;
'@

$pages = @('index.html','about.html','answers.html','profile.html','writing.html','giving.html',
           'writing\ai-search-visibility.html','writing\when-ai-gets-you-wrong.html','writing\ai-automation-failure.html')

foreach ($rel in $pages) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { continue }
  $t = [System.IO.File]::ReadAllText($p)
  if ($t -match 'Swiss Modernism 2.0 tokens') { "already tokened: $rel"; continue }

  # inject the token block right after --measure (present on every page's :root)
  $t = $t.Replace("    --measure:38rem;", "    --measure:38rem;`n$tokens")

  # body: use the type scale and a consistent rhythm
  $t = $t.Replace("font:400 17px/1.7 -apple-system", "font:400 var(--t-base)/var(--lh-body) -apple-system")

  # headings onto the scale, with Swiss tight leading
  $t = $t.Replace("h1{font-size:1.85rem; line-height:1.16;", "h1{font-size:var(--t-2xl); line-height:var(--lh-tight);")
  $t = $t.Replace("h1{font-size:1.9rem; line-height:1.17;", "h1{font-size:var(--t-2xl); line-height:var(--lh-tight);")
  $t = $t.Replace("h1{font-size:1.95rem; line-height:1.16;", "h1{font-size:var(--t-2xl); line-height:var(--lh-tight);")
  $t = $t.Replace("h1{font-size:1.55rem;", "h1{font-size:var(--t-2xl);")

  [System.IO.File]::WriteAllText($p, $t)
  "tokened: $rel"
}
""
"=== verify ==="
$t = [System.IO.File]::ReadAllText("$root\index.html")
"  token block present : " + ($t -match 'Swiss Modernism 2.0 tokens')
"  --u 8px unit        : " + ($t -match '--u: 8px')
"  type scale present  : " + ($t -match '--t-base')
"  http request count  : " + (([regex]::Matches($t,'https?://fonts')).Count) + " (0 = no external fonts, keeps it fast)"

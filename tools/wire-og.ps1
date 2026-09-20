# Adds the social card (og:image / twitter:image), upgrades twitter:card to
# summary_large_image, and adds the image to the page's JSON-LD.
# Idempotent: safe to run more than once.
$root = Split-Path -Parent $PSScriptRoot
$IMG  = "https://aaronstalberg.com/og-card.png"
$ALT  = "Aaron Stalberg - AI tools, automation and AI search visibility"

$pages = @(
  "index.html",
  "about.html",
  "giving.html",
  "writing.html",
  "writing\ai-search-visibility.html",
  "writing\when-ai-gets-you-wrong.html",
  "writing\ai-automation-failure.html"
)

foreach ($rel in $pages) {
    $path = Join-Path $root $rel
    if (-not (Test-Path $path)) { "MISSING: $rel"; continue }
    $t = [System.IO.File]::ReadAllText($path)
    $orig = $t.Clone()

    # 1. twitter:card -> summary_large_image
    $t = $t -replace '<meta name="twitter:card" content="summary">',
                     '<meta name="twitter:card" content="summary_large_image">'

    # 2. og:image + twitter:image, inserted after the twitter:card line
    if ($t -notmatch 'og:image') {
        $t = $t -replace '(<meta name="twitter:card" content="summary_large_image">)',
@"
`$1
<meta property="og:image" content="$IMG">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="$ALT">
<meta name="twitter:image" content="$IMG">
<meta name="twitter:image:alt" content="$ALT">
"@
    }

    # 3. image on the Person / Article JSON-LD
    if ($t -notmatch '"image"\s*:\s*"https://aaronstalberg\.com/og-card\.png"') {
        # home + about: Person-style blocks carry "url": "https://aaronstalberg.com/"
        $t = $t -replace '("url":\s*"https://aaronstalberg\.com/",)',
                          "`$1`n  `"image`": `"$IMG`","
        # articles: BlogPosting blocks carry a "url" ending in .html
        $t = $t -replace '("url":\s*"https://aaronstalberg\.com/[^"]+\.html",)',
                          "`$1`n  `"image`": `"$IMG`","
    }

    if ($t -ne $orig) {
        [System.IO.File]::WriteAllText($path, $t)
        "UPDATED: $rel"
    } else {
        "no change: $rel"
    }
}

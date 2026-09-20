# Adds the Questions page to the site navigation/footer of every page,
# and routes "get in touch" to the domain email address.
# Idempotent: safe to run repeatedly.
$root = "C:\dsh-temp\aaronstalberg-site"

# --- 1. footer links -------------------------------------------------------
# Each page's footer lists Home / About / Writing / Why I give.
# Insert a Questions link after the About link, once.
$footerPairs = @(
  @{ find = '<a href="/about.html">About</a> ·';            add = "`n      <a href=`"/answers.html`">Questions</a> ·" },
  @{ find = '<a href="/about.html">About</a> &middot;';     add = "`n      <a href=`"/answers.html`">Questions</a> &middot;" }
)

$pages = @(
  "about.html","giving.html","writing.html","answers.html",
  "writing\ai-search-visibility.html",
  "writing\when-ai-gets-you-wrong.html",
  "writing\ai-automation-failure.html"
)

foreach ($rel in $pages) {
    $path = Join-Path $root $rel
    if (-not (Test-Path $path)) { "MISSING: $rel"; continue }
    $t = [System.IO.File]::ReadAllText($path)
    $orig = $t.Clone()

    if ($t -match '"/answers\.html"') {
        # already linked somewhere — only add footer link if this is not answers.html itself
        if ($rel -notmatch 'answers\.html') { "already linked: $rel" }
    } else {
        foreach ($fp in $footerPairs) {
            $t = $t.Replace($fp.find, $fp.find + $fp.add)
        }
    }
    if ($t -ne $orig) { [System.IO.File]::WriteAllText($path, $t); "UPDATED footer: $rel" }
}

# --- 2. route contact to the domain email ---------------------------------
# about.html and writing.html both say contact is via ShowUp Labs.
$about = Join-Path $root "about.html"
$t = [System.IO.File]::ReadAllText($about)
if ($t -match 'quickest way to reach me is through <a href="https://www\.showuplabs\.com"') {
    $t = $t -replace '(?s)<p>The quickest way to reach me is through <a href="https://www\.showuplabs\.com" target="_blank" rel="noopener">ShowUp Labs</a>\.</p>',
        '<p>Email <a href="mailto:info@aaronstalberg.com">info@aaronstalberg.com</a> — that is the fastest'
        + "`n     route, and the right one for press, editorial and speaking enquiries. I am also reachable"
        + "`n     through <a href=`"https://www.showuplabs.com`" target=`"_blank`" rel=`"noopener`">ShowUp Labs</a>.</p>"
    [System.IO.File]::WriteAllText($about, $t)
    "UPDATED contact: about.html"
}

$writing = Join-Path $root "writing.html"
$t = [System.IO.File]::ReadAllText($writing)
if ($t -match 'the quickest way to reach me is through') {
    $t = $t -replace '(?s)If you want to know when something goes up, the quickest way to reach me is through\s*<a href="https://www\.showuplabs\.com" target="_blank" rel="noopener">ShowUp Labs</a>\.',
        'If you want to know when something goes up, email'
        + "`n     <a href=`"mailto:info@aaronstalberg.com`">info@aaronstalberg.com</a>."
    [System.IO.File]::WriteAllText($writing, $t)
    "UPDATED contact: writing.html"
}

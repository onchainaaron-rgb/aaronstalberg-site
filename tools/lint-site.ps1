# Lints the generated site: JSON-LD validity, tag balance, internal link targets,
# and forbidden-term check. Run before every commit.
$root = "C:\dsh-temp\aaronstalberg-site"

$pages = @(
  "index.html","about.html","giving.html","writing.html","answers.html",
  "writing\ai-search-visibility.html",
  "writing\when-ai-gets-you-wrong.html",
  "writing\ai-automation-failure.html"
)

$fail = 0

# strict forbidden terms (Aaron's instruction: no company name, no ICO/company detail)
$forbidden = 'disqualif|Insolvency Service|Information Commissioner|nuisance|PECR|unscrupulous|CIB58196|Cross Deliveries|Lead Experts|09830112|115,341|£70,000|Lad Media|Lab Media'

foreach ($rel in $pages) {
    $path = Join-Path $root $rel
    if (-not (Test-Path $path)) { "MISSING FILE: $rel"; $fail++; continue }
    $t = [System.IO.File]::ReadAllText($path)
    $notes = @()

    # title / description / canonical presence
    if ($t -notmatch '<title>[^<]+</title>')                 { $notes += "no <title>" }
    if ($t -notmatch 'name="description"\s+content="[^"]+"')  { $notes += "no meta description" }
    if ($t -notmatch 'rel="canonical"')                       { $notes += "no canonical" }
    if ($t -notmatch 'og:image')                              { $notes += "no og:image" }
    if ($t -notmatch 'twitter:image')                         { $notes += "no twitter:image" }

    # canonical must be absolute and match the file
    $canon = [regex]::Match($t,'rel="canonical"\s+href="([^"]+)"').Groups[1].Value
    $expect = "https://aaronstalberg.com/" + ($rel -replace '\\','/')
    if ($rel -eq 'index.html') { $expect = "https://aaronstalberg.com/" }
    if ($canon -and $canon -ne $expect) { $notes += "canonical '$canon' != expected '$expect'" }

    # JSON-LD validity
    $blocks = [regex]::Matches($t, '(?s)<script type="application/ld\+json">(.*?)</script>')
    if ($blocks.Count -eq 0) { $notes += "no JSON-LD" }
    foreach ($b in $blocks) {
        try { $null = $b.Groups[1].Value | ConvertFrom-Json }
        catch { $notes += "invalid JSON-LD: $($_.Exception.Message)" }
    }

    # tag balance (rough)
    foreach ($tag in @('div','p','ul','li','main','footer','h1','h2','h3','script','style')) {
        $open  = ([regex]::Matches($t, "<$tag[\s>]")).Count
        $close = ([regex]::Matches($t, "</$tag>")).Count
        if ($open -ne $close) { $notes += "<$tag> unbalanced ($open open / $close close)" }
    }

    # unclosed <a> (common breakage)
    $ao = ([regex]::Matches($t,'<a[\s>]')).Count
    $ac = ([regex]::Matches($t,'</a>')).Count
    if ($ao -ne $ac) { $notes += "<a> unbalanced ($ao open / $ac close)" }

    # forbidden terms
    $hits = [regex]::Matches($t, $forbidden, 'IgnoreCase') | ForEach-Object { $_.Value } | Sort-Object -Unique
    if ($hits) { $notes += "FORBIDDEN TERMS: $($hits -join ', ')" }

    if ($notes.Count) {
        $fail++
        "FAIL $rel"
        $notes | ForEach-Object { "       - $_" }
    } else {
        "ok   $rel"
    }
}

# ---- internal link targets resolve as files -------------------------------
""
"--- internal link targets ---"
$allLinks = @()
foreach ($rel in $pages) {
    $t = [System.IO.File]::ReadAllText((Join-Path $root $rel))
    foreach ($m in [regex]::Matches($t, 'href="(/[^"#?]*)"')) {
        $allLinks += [pscustomobject]@{ From = $rel; Href = $m.Groups[1].Value }
    }
}
foreach ($l in ($allLinks | Sort-Object Href -Unique)) {
    $target = $l.Href.TrimStart('/')
    if ($target -eq '') { continue }
    $full = Join-Path $root ($target -replace '/','\')
    if (-not (Test-Path $full)) {
        # allow extensionless -> .html
        if (Test-Path ($full + '.html')) { "     note  $($l.Href) resolves as .html" }
        else { "BROKEN $($l.Href)  (from $($l.From))"; $fail++ }
    }
}

""
if ($fail -eq 0) { "ALL CHECKS PASSED" } else { "$fail problem(s) found" }

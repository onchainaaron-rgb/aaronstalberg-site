# strip-lift-toggle.ps1 — Remove the liftable-sentence toggle.
#
# WHY: it highlighted only 2 sentences out of the many quotable ones, the pattern
# matching was unreliable, and it duplicated something the site already does properly
# and properly-indexably: profile.html, answers.html and llms.txt ARE the quotable
# statements, written deliberately. A half-working highlight adds noise to the page
# that ranks #1. Cut it; keep the motion, which works.

$root = "C:\dsh-temp\aaronstalberg-site"
$pages = @('index.html','about.html','answers.html','profile.html','writing.html','giving.html',
           'writing\ai-search-visibility.html','writing\when-ai-gets-you-wrong.html','writing\ai-automation-failure.html')

foreach ($rel in $pages) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { continue }
  $t = [System.IO.File]::ReadAllText($p)
  $before = $t.Length

  # 1. drop the lift CSS block, anchored on stable markers
  $a = $t.IndexOf("/* liftable-sentence highlight")
  $b = $t.IndexOf("/* while lift mode is on")
  if ($a -ge 0 -and $b -gt $a) { $t = $t.Remove($a, $b - $a) }

  # 2. drop the lift JS block, anchored on stable markers
  $x = $t.IndexOf("/* ---------- liftable sentences")
  $y = $t.IndexOf("if (window.console && console.debug)")
  if ($x -ge 0 -and $y -gt $x) {
    $end = $t.IndexOf("`n", $y)
    if ($end -gt $y) { $t = $t.Remove($x, $end - $x) }
  }

  # 3. remove the orphaned rule that the block removal left behind
  $o = $t.IndexOf("/* while lift mode is on")
  if ($o -ge 0) {
    $close = $t.IndexOf("}", $o)
    if ($close -gt $o) { $t = $t.Remove($o, ($close - $o) + 1) }
  }

  [System.IO.File]::WriteAllText($p, $t)
  "cleaned: $rel  ($before -> $($t.Length) bytes)"
}
""
"=== verify ==="
$t = [System.IO.File]::ReadAllText("$root\index.html")
"  references to .lift : " + (([regex]::Matches($t,'class="lift"')).Count)
"  toggle present      : " + ($t -match 'toggle-lift')
"  lift CSS present    : " + ($t -match 'liftable-sentence')
"  reveal system intact: " + ($t -match 'js-anim')
"  fail-safe intact    : " + ($t -match 'FAIL-SAFE')
"  script blocks       : " + (([regex]::Matches($t,'<script')).Count)

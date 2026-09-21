# fix-interaction.ps1 — Replace the broken interaction layer with a correct one.
#
# THE BUG BEING FIXED: the first version set opacity:0 on .reveal in CSS, so if the
# IntersectionObserver did not fire (or JS failed), content was PERMANENTLY INVISIBLE.
# 10 of 14 elements were stuck hidden. That also breaks SEO and any reader with JS off.
#
# THE RULE NOW: content is visible by default. The script opts elements INTO the
# hidden state only when it can guarantee it will also un-hide them.
#
# Also corrected against the UI design rules:
#  - micro-interactions 150-300ms (was 550ms)
#  - no layout shift: reveal uses opacity only, no translateY
#  - aria on interactive elements (was title-only)
#  - a fail-safe timeout guarantees nothing stays hidden

$root = "C:\dsh-temp\aaronstalberg-site"

$oldCss = @'
/* ===== interaction layer ===== */
@media (prefers-reduced-motion: no-preference){
  .reveal{opacity:0; transform:translateY(10px);
    transition:opacity .55s cubic-bezier(.2,.7,.2,1), transform .55s cubic-bezier(.2,.7,.2,1)}
  .reveal.in{opacity:1; transform:none}
'@

$newCss = @'
/* ===== interaction layer (v2) =====
   Content is VISIBLE BY DEFAULT. The .js-anim class is added by script only when
   the observer is definitely available, so a failure can never hide content. */
.js-anim .reveal{opacity:0; transition:opacity .26s cubic-bezier(.2,.7,.2,1)}
.js-anim .reveal.in{opacity:1}
@media (prefers-reduced-motion: reduce){
  .js-anim .reveal{opacity:1 !important; transition:none !important}
}
@media (prefers-reduced-motion: no-preference){
'@

# ---------------------------------------------------------------- replacement JS
$newJs = @'
<script>
(function(){
  "use strict";
  var doc = document, reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var hasIO = "IntersectionObserver" in window;

  /* ---------- scroll progress (safe: fixed, pointer-events none) ---------- */
  if (!reduce) {
    var bar = doc.createElement("div");
    bar.id = "prog";
    bar.setAttribute("aria-hidden", "true");
    bar.style.cssText = "position:fixed;top:0;left:0;height:2px;width:0;z-index:20;pointer-events:none;background:linear-gradient(90deg,#1f4e79,#4d8fc4)";
    doc.body.appendChild(bar);
    var queued = false;
    var paint = function(){
      var max = doc.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (max > 0 ? (window.scrollY / max) * 100 : 0) + "%";
      queued = false;
    };
    window.addEventListener("scroll", function(){
      if (!queued) { queued = true; requestAnimationFrame(paint); }
    }, { passive: true });
    paint();
  }

  /* ---------- reveal on scroll ----------
     Opt in only when we can guarantee the un-hide, and add a hard fail-safe. */
  if (!reduce && hasIO) {
    doc.documentElement.classList.add("js-anim");
    var seen = [];
    var show = function(el){ el.classList.add("in"); };
    var io = new IntersectionObserver(function(entries){
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].isIntersecting) { show(entries[i].target); io.unobserve(entries[i].target); }
      }
    }, { rootMargin: "0px 0px -6% 0px", threshold: 0.01 });

    var targets = doc.querySelectorAll("main > h2, main > ul, main > p, .proj, .post, .q, footer");
    Array.prototype.forEach.call(targets, function(el, i){
      el.classList.add("reveal");
      el.style.transitionDelay = Math.min(i % 3, 2) * 45 + "ms";
      seen.push(el);
      io.observe(el);
    });

    /* FAIL-SAFE: anything still hidden after 2.5s is shown regardless.
       This is the guarantee the first version lacked. */
    setTimeout(function(){
      Array.prototype.forEach.call(seen, function(el){ el.classList.add("in"); });
    }, 2500);
  }

  /* ---------- liftable sentences ----------
     Match on each element's plain text and wrap with a tolerant, word-based regex.
     The previous version walked text nodes with /g regexes and matched almost nothing. */
  var PATTERNS = [
    /Aaron Stalberg builds AI tools and AI-powered businesses\.?/i,
    /Founder of ShowUp Labs[^.]{0,140}\./i,
    /an AI search visibility product that measures whether AI assistants recommend a business/i,
    /(?:and of )?AutoCoreAgent, an AI automation product/i,
    /how AI systems decide what to show people/i,
    /I build AI tools and businesses that run on AI/i,
    /I build AI tools and AI-powered businesses/i,
    /Builder of AI tools/i,
    /the founder of ShowUp Labs/i,
    /AI search visibility product/i
  ];

  var LEAF_OK = /^(P|LI|DD|DT|H1|H2|H3|BLOCKQUOTE|SPAN|STRONG|EM|DIV|TD|FIGCAPTION)$/;
  var made = 0;

  function markEl(el) {
    if (!el || el.nodeType !== 1) return;
    if (el.querySelector && el.querySelector(".lift")) return;
    if (el.closest && el.closest(".lift")) return;
    // find the deepest child whose own text still contains a full match
    var kids = el.children;
    for (var i = 0; i < kids.length; i++) {
      if (!LEAF_OK.test(kids[i].tagName)) continue;
      var kt = kids[i].textContent || "";
      if (PATTERNS.some(function(re){ return re.test(kt); })) { markEl(kids[i]); return; }
    }
    var text = el.textContent || "";
    if (!text.trim()) return;
    // if this element has element children we did not descend into, work on its own text only
    var target = null;
    for (var j = 0; j < PATTERNS.length && !target; j++) {
      var m = PATTERNS[j].exec(text);
      if (m) target = m[0];
    }
    if (!target || text.indexOf(target) < 0) return;
    // only replace when the element's content is a single text node (safe)
    if (el.childNodes.length !== 1 || el.childNodes[0].nodeType !== 3) return;

    var txt = el.textContent, idx = txt.indexOf(target);
    if (idx < 0) return;
    var before = txt.slice(0, idx), after = txt.slice(idx + target.length);
    var span = doc.createElement("span");
    span.className = "lift";
    span.setAttribute("role", "mark");
    span.setAttribute("aria-label", "Quotable statement: " + target.replace(/\s+/g, " ").trim());
    span.textContent = target;
    el.textContent = "";
    if (before) el.appendChild(doc.createTextNode(before));
    el.appendChild(span);
    if (after) el.appendChild(doc.createTextNode(after));
    made++;
  }

  Array.prototype.forEach.call(doc.querySelectorAll("main p, main li, main dd, main h2, .lead, .standfirst"), markEl);

  /* ---------- the toggle ---------- */
  var total = doc.querySelectorAll(".lift").length;
  if (total > 0) {
    var host = doc.querySelector("main > p.lead") || doc.querySelector("main > p");
    if (host && host.parentNode) {
      var wrap = doc.createElement("div");
      var btn = doc.createElement("button");
      btn.type = "button";
      btn.className = "toggle-lift";
      btn.setAttribute("aria-pressed", "false");
      btn.setAttribute("aria-label", "Highlight the sentences on this page that an AI assistant can quote");
      btn.innerHTML = '<span class="sw" aria-hidden="true"></span><span>Show the ' + total + ' sentences an AI can quote</span>';
      var note = doc.createElement("p");
      note.className = "lift-note";
      note.textContent = "These are the short, checkable statements on this page. Assistants favour text that is specific and easy to lift, which is why they are written this way.";
      wrap.appendChild(btn);
      host.parentNode.insertBefore(wrap, host.nextSibling);
      wrap.appendChild(note);
      btn.addEventListener("click", function(){
        var on = btn.getAttribute("aria-pressed") === "true";
        btn.setAttribute("aria-pressed", String(!on));
        doc.body.classList.toggle("lifting", !on);
        note.classList.toggle("in", !on);
      });
    }
  }

  if (window.console && console.debug) console.debug("[site] lift spans:", total);
})();
</script>
'@

$pages = @('index.html','about.html','answers.html','profile.html','writing.html','giving.html',
           'writing\ai-search-visibility.html','writing\when-ai-gets-you-wrong.html','writing\ai-automation-failure.html')

foreach ($rel in $pages) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { continue }
  $t = [System.IO.File]::ReadAllText($p)

  # 1. swap the broken CSS block for the safe one
  if ($t.Contains($oldCss)) {
    $t = $t.Replace($oldCss, $newCss)
    "css fixed: $rel"
  }

  # 2. remove the old script entirely (everything from the first inline <script> that
  #    is NOT ld+json, up to its closing tag) and insert the new one
  $t = [regex]::Replace($t, '(?s)<script>\s*\(function\(\)\{\s*"use strict";.*?</script>', $newJs.Trim())

  [System.IO.File]::WriteAllText($p, $t)
}
""
"done — all pages now have the safe interaction layer"

# enhance-site.ps1 — Add tasteful interactive motion to the site.
#
# Design rules (deliberate, so this stays fast and credible):
#  - ONLY CSS transforms and opacity animate. No layout thrash.
#  - prefers-reduced-motion fully respected — content visible by default.
#  - No libraries. Site is crawled and must stay light.
#  - Progressive enhancement: with JS off, everything is readable.
#
# Run: pwsh -File tools\enhance-site.ps1

$root = "C:\dsh-temp\aaronstalberg-site"

# ---------------------------------------------------------------- shared CSS
$css = @'

/* ===== interaction layer ===== */
@media (prefers-reduced-motion: no-preference){
  .reveal{opacity:0; transform:translateY(10px);
    transition:opacity .55s cubic-bezier(.2,.7,.2,1), transform .55s cubic-bezier(.2,.7,.2,1)}
  .reveal.in{opacity:1; transform:none}

  /* cards lift and their edge picks up the accent */
  .proj{transition:transform .28s cubic-bezier(.2,.7,.2,1), border-color .28s ease, box-shadow .28s ease}
  .proj:hover{transform:translateY(-2px); border-color:var(--accent-soft);
    box-shadow:0 6px 22px rgba(31,78,121,.09)}

  /* social pills */
  .socials a{transition:border-color .2s ease, color .2s ease, transform .2s ease}
  .socials a:hover{transform:translateY(-1px)}

  /* tags */
  .tags li{transition:background-color .2s ease, color .2s ease, transform .2s ease}
  .tags li:hover{transform:translateY(-1px); color:var(--accent)}

  /* the monogram gets a slow, subtle sheen once */
  .mark{position:relative; overflow:hidden}
  .mark::after{content:""; position:absolute; inset:0;
    background:linear-gradient(115deg, transparent 35%, rgba(255,255,255,.22) 50%, transparent 65%);
    transform:translateX(-120%); animation:sheen 2.6s cubic-bezier(.3,.6,.2,1) .35s 1}
  @keyframes sheen{to{transform:translateX(120%)}}
}

/* liftable-sentence highlight — the interactive idea.
   Marks the phrases an assistant can quote verbatim. */
.lift{cursor:help; border-bottom:1px dashed var(--accent-soft);
  transition:background-color .22s ease, border-color .22s ease, color .22s ease;
  border-radius:2px; padding:0 .06em}
.lift:hover, .lift.on{background:rgba(31,78,121,.09); border-bottom-color:var(--accent)}

.toggle-lift{display:inline-flex; align-items:center; gap:.42rem;
  font-size:.78rem; color:var(--muted); background:none; border:0; padding:.2rem 0;
  cursor:pointer; font-family:inherit; margin:0 0 1.1rem}
.toggle-lift:hover{color:var(--accent)}
.toggle-lift .sw{width:26px; height:15px; border-radius:9px; background:var(--rule);
  position:relative; transition:background-color .22s ease; flex:0 0 auto}
.toggle-lift .sw::after{content:""; position:absolute; top:2px; left:2px; width:11px; height:11px;
  border-radius:50%; background:#fff; box-shadow:0 1px 2px rgba(0,0,0,.2);
  transition:transform .22s cubic-bezier(.2,.7,.2,1)}
.toggle-lift[aria-pressed="true"] .sw{background:var(--accent)}
.toggle-lift[aria-pressed="true"] .sw::after{transform:translateX(11px)}

.lift-note{font-size:.86rem; color:var(--muted); margin:-.4rem 0 1.4rem;
  max-height:0; overflow:hidden; opacity:0;
  transition:max-height .3s ease, opacity .3s ease, margin .3s ease}
.lift-note.in{max-height:5rem; opacity:1}

/* while lift mode is on, mark the quotable spans visually */
body.lifting .lift{background:rgba(31,78,121,.07)}

/* scroll progress — one hairline, no layout impact */
#prog{position:fixed; top:0; left:0; height:2px; width:0;
  background:linear-gradient(90deg, var(--accent), #4d8fc4); z-index:50;
  transition:width .1s linear}
@media (prefers-reduced-motion: reduce){ #prog{display:none} }
'@

# ---------------------------------------------------------------- shared JS
$js = @'
<script>
(function(){
  "use strict";
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---- scroll progress ---- */
  if (!reduce) {
    var bar = document.createElement("div");
    bar.id = "prog";
    document.body.appendChild(bar);
    var tick = false;
    var upd = function(){
      var h = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (h > 0 ? (window.scrollY / h) * 100 : 0) + "%";
      tick = false;
    };
    window.addEventListener("scroll", function(){
      if (!tick) { tick = true; requestAnimationFrame(upd); }
    }, { passive: true });
    upd();
  }

  /* ---- reveal on scroll ---- */
  var targets = document.querySelectorAll("main > *:not(header):not(script), .proj, .post, .q, footer");
  if (reduce || !("IntersectionObserver" in window)) {
    Array.prototype.forEach.call(targets, function(el){ el.classList.add("reveal","in"); });
  } else {
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(e){
        if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.05 });
    Array.prototype.forEach.call(targets, function(el, i){
      el.classList.add("reveal");
      el.style.transitionDelay = Math.min(i % 4, 3) * 55 + "ms";
      io.observe(el);
    });
  }

  /* ---- liftable-sentence highlighter ----
     Marks the short factual phrases an assistant can quote verbatim.
     This is a demonstration of the craft, not decoration. */
  var LIFTABLE = [
    /Aaron Stalberg builds AI tools and AI-powered businesses/g,
    /Founder of ShowUp Labs[^.]*\./g,
    /an AI search visibility product that measures whether AI assistants recommend a business/g,
    /AutoCoreAgent, an AI automation product/g,
    /how AI systems decide what to show people/g,
    /I build AI tools and businesses that run on AI/g
  ];

  var liftCount = 0;
  var walker = document.createTreeWalker(document.querySelector("main"), NodeFilter.SHOW_TEXT, {
    acceptNode: function(n){
      if (!n.nodeValue || !n.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
      var p = n.parentNode;
      if (!p || /^(SCRIPT|STYLE|A|CODE|BUTTON)$/.test(p.nodeName)) return NodeFilter.FILTER_REJECT;
      if (p.classList && p.classList.contains("lift")) return NodeFilter.FILTER_REJECT;
      for (var i = 0; i < LIFTABLE.length; i++) { if (LIFTABLE[i].test(n.nodeValue)) return NodeFilter.FILTER_ACCEPT; }
      return NodeFilter.FILTER_REJECT;
    }
  });

  var nodes = [], n;
  while ((n = walker.nextNode())) nodes.push(n);

  nodes.forEach(function(node){
    var text = node.nodeValue, frag = document.createDocumentFragment(), last = 0, hit = null;
    for (var i = 0; i < LIFTABLE.length; i++) {
      LIFTABLE[i].lastIndex = 0;
      var m;
      while ((m = LIFTABLE[i].exec(text)) !== null) {
        if (m.index < last) continue;
        if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
        var span = document.createElement("span");
        span.className = "lift";
        span.textContent = m[0];
        span.title = "A short, checkable statement \u2014 the kind an AI assistant can quote verbatim.";
        frag.appendChild(span);
        hit = true;
        last = m.index + m[0].length;
      }
    }
    if (!hit) return;
    if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
    liftCount++;
    node.parentNode.replaceChild(frag, node);
  });

  /* ---- the toggle ---- */
  var total = document.querySelectorAll(".lift").length;
  if (total > 0) {
    var host = document.querySelector("main > p.lead") || document.querySelector("main > p");
    if (host && host.parentNode) {
      var wrap = document.createElement("div");
      var btn = document.createElement("button");
      btn.className = "toggle-lift";
      btn.setAttribute("aria-pressed", "false");
      btn.type = "button";
      btn.innerHTML = '<span class="sw" aria-hidden="true"></span><span>Show the ' + total + ' sentences an AI can quote</span>';
      var note = document.createElement("p");
      note.className = "lift-note";
      note.textContent = "These are the short, checkable statements on this page. Assistants favour text that is specific and easy to lift, which is why they are written this way. Hover any one to see it marked.";
      wrap.appendChild(btn);
      host.parentNode.insertBefore(wrap, host.nextSibling);
      wrap.appendChild(note);
      btn.addEventListener("click", function(){
        var on = btn.getAttribute("aria-pressed") === "true";
        btn.setAttribute("aria-pressed", on ? "false" : "true");
        document.body.classList.toggle("lifting", !on);
        note.classList.toggle("in", !on);
        var spans = document.querySelectorAll(".lift");
        Array.prototype.forEach.call(spans, function(s){ s.classList.toggle("on", !on); });
      });
    }
  }

  /* ---- active section in the crumb nav, where a nav exists ---- */
  var heads = document.querySelectorAll("main > h2");
  if (heads.length && !reduce) {
    Array.prototype.forEach.call(heads, function(h){ h.classList.add("reveal"); });
  }
})();
</script>
'@

$pages = @('index.html','about.html','answers.html','profile.html','writing.html','giving.html',
           'writing\ai-search-visibility.html','writing\when-ai-gets-you-wrong.html','writing\ai-automation-failure.html')

$changed = 0
foreach ($rel in $pages) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { "missing: $rel"; continue }
  $t = [System.IO.File]::ReadAllText($p)
  if ($t -match 'interaction layer') { "already enhanced: $rel"; continue }

  $t = $t.Replace('</style>', $css + "`n</style>")
  if ($t -match '(?s)</body>') {
    $t = $t -replace '(?s)</body>', ($js + "`n</body>")
  }
  [System.IO.File]::WriteAllText($p, $t)
  "enhanced: $rel"
  $changed++
}
""
"changed $changed page(s)"

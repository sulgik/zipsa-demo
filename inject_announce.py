"""Inject demo announcement banner into chat.html at build time."""

with open("/app/source/ui/chat.html") as f:
    content = f.read()

# 1. Add CSS for the announcement bar
css_inject = """
  /* DEMO ANNOUNCEMENT BAR */
  #demo-announce {
    background: #050e1a;
    border-bottom: 2px solid #1e3550;
    padding: 7px 20px;
    font-size: 11px;
    color: var(--lgray);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 20px;
    flex-shrink: 0;
    flex-wrap: wrap;
  }
  #demo-announce .ann-label { color: var(--yellow); font-weight: 700; letter-spacing: 1px; }
  #demo-announce .ann-sep   { color: var(--border); }
  #demo-announce .ann-local    { color: var(--yellow); font-weight: 600; }
  #demo-announce .ann-external { color: var(--blue);   font-weight: 600; }
"""
content = content.replace("</style>", css_inject + "\n</style>", 1)

# 2. Insert banner HTML right after <body>
banner_html = """\n<div id="demo-announce">
  <span class="ann-label">&#9432;&nbsp;DEMO</span>
  <span>
    Local AI:&nbsp;<span class="ann-local" id="ann-local">Qwen3.5-27b</span>
    &nbsp;&mdash;&nbsp;simulating on-prem trust zone (OpenRouter)
  </span>
  <span class="ann-sep">|</span>
  <span>
    External AI:&nbsp;<span class="ann-external" id="ann-external">Claude Sonnet 4.5</span>
    &nbsp;&mdash;&nbsp;high-capability cloud model (Anthropic via OpenRouter)
  </span>
</div>
"""
content = content.replace("<body>", "<body>" + banner_html, 1)

# 3. Extend loadModelInfo() to also populate the announcement bar
old_js = "    document.getElementById('model-local').textContent    = 'Local: '    + shortLocal;"
new_js = (
    "    document.getElementById('model-local').textContent    = 'Local: '    + shortLocal;\n"
    "    const annLocal = document.getElementById('ann-local');\n"
    "    const annExt   = document.getElementById('ann-external');\n"
    "    if (annLocal) annLocal.textContent = local    || shortLocal;\n"
    "    if (annExt)   annExt.textContent   = external || shortExternal;"
)
content = content.replace(old_js, new_js)

with open("/app/source/ui/chat.html", "w") as f:
    f.write(content)

print("Announcement banner injected successfully.")

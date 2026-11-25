"""Translation jobs for the guides: what is left to translate, and folding translations into a .po file.

  python3 -I po/i18n.py jobs  messages.pot po/zh-CN.po JOBDIR
      One JSON file per guide page in JOBDIR, [{"id": n, "msgid": "..."}], holding the messages
      of the guides that zh-CN.po does not translate yet. The command pages, the command line help
      and the changelog stay English.
  python3 -I po/i18n.py merge messages.pot po/zh-CN.po JOBDIR OUTDIR build/src build/html
      Adds the translations in OUTDIR/<page>.json ({"id": "translation"}) to zh-CN.po. An id left
      out stays English (msgstr = msgid), so the next jobs run does not offer it again. A translated
      heading gets the English page's anchor, so links between pages keep working.

messages.pot comes from the assembled English pages (build.sh, then the xgettext renderer; see README.md).
"""
import html, json, os, re, sys

GUIDES = ["index", "SUMMARY", "getting-started", "install", "window", "command-line",
          "databases", "ai-agents", "connect", "mcp", "plugins"]


def parse(path):
    """Entries of a .po or .pot file as (msgid, msgstr, pages)."""
    out = []
    for block in open(path, encoding="utf-8").read().split("\n\n"):
        refs = re.findall(r"^#: (.+)$", block, re.M)
        parts = {}
        for key in ("msgid", "msgstr"):
            m = re.search(rf'^{key} ((?:".*"\n?)+)', block, re.M)
            parts[key] = "".join(json.loads(s) for s in re.findall(r'^(".*")$', m.group(1), re.M)) if m else ""
        if parts["msgid"]:
            pages = [os.path.basename(r.split(":")[0])[:-3] for r in refs if "/commands/" not in r]
            out.append((parts["msgid"], parts["msgstr"], pages))
    return out


def guide_messages(pot):
    """(page, msgid) for every message of the guides; a message on several pages goes to the first."""
    for msgid, _, pages in parse(pot):
        if msgid.startswith('<p class="sc-version">'):
            continue  # the release line on every page changes with every release
        page = next((p for p in GUIDES if p in pages), None)
        if page:
            yield page, msgid


def anchors(src, site):
    """Heading text in the Markdown -> the id the English site gives it, where that is unique."""
    seen = {}
    for page in GUIDES[2:] + ["index"]:
        md = open(f"{src}/{page}.md", encoding="utf-8").read()
        md = re.sub(r"^```.*?^```", "", md, flags=re.M | re.S)
        heads = [h for h in re.findall(r"^#{2,6} (.+?)\s*$", md, re.M)]  # h1 is the page title, shared with the sidebar
        ids = re.findall(r'<h[2-6] id="([^"]+)"', open(f"{site}/{page}.html", encoding="utf-8").read())
        if len(heads) != len(ids):
            sys.exit(f"{page}: {len(heads)} headings in the Markdown, {len(ids)} in the page")
        for h, i in zip(heads, ids):
            seen.setdefault(h, set()).add(html.unescape(i))
    return {h: ids.pop() for h, ids in seen.items() if len(ids) == 1}


def quote(s):
    if not s:
        return '""'
    lines = s.split("\n")
    body = [json.dumps(l + "\n", ensure_ascii=False) for l in lines[:-1]] + [json.dumps(lines[-1], ensure_ascii=False)]
    body = [b for b in body if b != '""']
    return body[0] if len(body) == 1 else '""\n' + "\n".join(body)


def write_po(path, entries, lang):
    head = ("Project-Id-Version: Statscraft documentation\nPOT-Creation-Date: \nPO-Revision-Date: \n"
            "Last-Translator: \nLanguage-Team: \n"
            f"Language: {lang}\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n"
            "Content-Transfer-Encoding: 8bit\nPlural-Forms: nplurals=1; plural=0;\n")
    with open(path, "w", encoding="utf-8") as f:
        f.write(f'msgid ""\nmsgstr {quote(head)}\n')
        for msgid, msgstr in entries:
            f.write(f"\nmsgid {quote(msgid)}\nmsgstr {quote(msgstr)}\n")


def main():
    cmd, pot, po = sys.argv[1:4]
    lang = os.path.basename(po)[:-3]
    done = {m: s for m, s, _ in parse(po)} if os.path.exists(po) else {}
    todo = [(p, m) for p, m in guide_messages(pot) if not done.get(m)]
    jobs = sys.argv[4]
    if cmd == "jobs":
        os.makedirs(jobs, exist_ok=True)
        for page in GUIDES:
            items = [{"id": i, "msgid": m} for i, (p, m) in enumerate(todo) if p == page]
            if items:
                json.dump(items, open(f"{jobs}/{page}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
                print(page, len(items))
    elif cmd == "merge":
        outdir, src, site = sys.argv[5:8]
        ids = anchors(src, site)
        for page in GUIDES:
            if not os.path.exists(f"{outdir}/{page}.json"):
                continue
            job = {str(x["id"]): x["msgid"] for x in json.load(open(f"{jobs}/{page}.json", encoding="utf-8"))}
            got = json.load(open(f"{outdir}/{page}.json", encoding="utf-8"))
            for msgid in job.values():
                if not done.get(msgid):
                    done[msgid] = msgid  # left out on purpose: stays English
            for k, text in got.items():
                if k not in job:
                    print(f"{page}: id {k} is not in the job, skipped", file=sys.stderr)
                    continue
                msgid = job[k]
                if msgid in ids and page != "SUMMARY" and "{#" not in text:
                    text = f"{text} {{#{ids[msgid]}}}"
                done[msgid] = text
        # A heading that is also a sidebar title cannot carry {#id} (the sidebar would show it): its
        # translated heading gets the id mdBook makes from the text, and links to it follow.
        for page, msgid in guide_messages(pot):
            if page == "SUMMARY" and msgid in ids and done.get(msgid):
                new = "".join(c.lower() if c.isalnum() or c in "_-" else "-" if c.isspace() else "" for c in done[msgid])
                for m, s in done.items():
                    done[m] = s.replace(f"#{ids[msgid]})", f"#{new})")
        order = [m for _, m in guide_messages(pot)]
        keep = [(m, done.get(m, "")) for m in order]  # messages no longer in the pages are dropped
        write_po(po, keep, lang)
        print(f"{len(keep)} messages: {sum(1 for m, s in keep if s and s != m)} translated, {sum(1 for m, s in keep if s == m)} kept English, {sum(1 for _, s in keep if not s)} open")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

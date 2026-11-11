#!/usr/bin/env bash
# Builds the documentation site for one Statscraft release.
# Usage: ./build.sh [TAG]   TAG defaults to the newest release, for example v0.1.1.
# Needs gh (signed in, or GH_TOKEN set), curl, tar, sha256sum, and mdbook on PATH or in $MDBOOK.
# The pages are assembled in build/src and the site is written to build/html.
set -euo pipefail

repo=statscrafthq/statscraft
root=$(cd "$(dirname "$0")" && pwd)
tag=${1:-$(gh release view -R "$repo" --json tagName -q .tagName)}
version=${tag#v}
out=$root/build
dl=$out/dl
src=$out/src
rm -rf "$out"
mkdir -p "$dl/source" "$src"

# The release: its Linux binary, checked against SHA256SUMS, and the source at its tag.
gh release download "$tag" -R "$repo" -D "$dl" -p "statscraft-$version-linux-x86_64.tar.gz" -p SHA256SUMS
(cd "$dl" && sha256sum -c --ignore-missing SHA256SUMS)
tar -xzf "$dl/statscraft-$version-linux-x86_64.tar.gz" -C "$dl"
bin=$dl/statscraft-$version-linux-x86_64/bin/statscraft
"$bin" --version | grep -qx "statscraft $version" || { echo "binary does not report version $version" >&2; exit 1; }
gh api "repos/$repo/tarball/$tag" | tar -xz -C "$dl/source" --strip-components=1

# Hand-written pages, copied as they are at the tag. The commands folder is replaced by the generated one.
cp -R "$dl/source/docs/." "$src/"
rm -rf "$src/commands"
mkdir "$src/commands"
# The README up to its list of documents is the start page; the sidebar replaces that list.
awk '/^## Documentation/ { exit } { print }' "$dl/source/README.md" > "$src/index.md"
cp "$dl/source/CHANGELOG.md" "$src/changelog.md"
# The v0.1.1 pages quote an error code that holds a vendor name; later releases leave the code out too.
for f in "$src"/*.md; do
  sed -i -E 's/"code":"unsupported_[a-z]+_command",//g' "$f"
  sed -i -e 's#](docs/#](#g' -e 's#](CHANGELOG\.md#](changelog.md#g' -e 's#commands/README\.md#commands/index.md#g' "$f"
done

# Command reference, generated from the help of the release binary.
"$bin" help > "$dl/help.txt"
{
  echo "# Commands"
  echo
  echo "One page per supported command, generated from \`statscraft help\` of Statscraft $version."
  echo
  echo "| Command | What it does |"
  echo "|---|---|"
} > "$src/commands/index.md"
summary_cmds=""
# The list holds the name padded to 18 characters, then the summary; a longer name runs into it.
while IFS= read -r line; do
  name=$(printf '%s' "${line:2:18}" | sed 's/ *$//')
  slug=$(printf '%s' "$name" | tr 'A-Z ' 'a-z-')
  "$bin" help "$name" > "$dl/help-$slug.txt"
  first=$(head -n 1 "$dl/help-$slug.txt")
  [[ $first == "$name: "* ]] || { echo "unexpected help for $name: $first" >&2; exit 1; }
  echo "| [$name]($slug.md) | ${first#"$name: "} |" >> "$src/commands/index.md"
  summary_cmds+="  - [$name](commands/$slug.md)"$'\n'
  # "NAME: summary", then sections such as "Syntax:" and "Example:" whose text is indented by two spaces.
  awk '
    function flush() {
      while (n > 0 && buf[n] == "") n--
      if (n > 0) { print "```text"; for (i = 1; i <= n; i++) print buf[i]; print "```"; print "" }
      n = 0
    }
    NR == 1 { p = index($0, ": "); print "# " substr($0, 1, p - 1); print ""; print substr($0, p + 2); print ""; next }
    /^[A-Z][A-Za-z ]*:$/ { flush(); print "## " substr($0, 1, length($0) - 1); print ""; insec = 1; next }
    insec { sub(/^  /, ""); if (n > 0 || $0 != "") buf[++n] = $0; next }
    { print }
    END { flush() }
  ' "$dl/help-$slug.txt" > "$src/commands/$slug.md"
  echo "\`statscraft help $name\` prints the same text in the terminal. [All commands](index.md)" >> "$src/commands/$slug.md"
done < <(sed -n '/^Supported commands:/,/^$/p' "$dl/help.txt" | sed '1d;/^$/d')
[ -n "$summary_cmds" ] || { echo "no commands found in statscraft help" >&2; exit 1; }
{
  echo
  echo "## General rules"
  echo
  echo '```text'
  sed -n '/^General rules:/,$p' "$dl/help.txt" | sed '1d;s/^  //'
  echo '```'
} >> "$src/commands/index.md"
# The list of recognized but unsupported commands is not in the help; carry it over from the
# command pages at the tag. Without it, links to the section go to the top of the index instead.
unsupported=$(awk '/^## Not supported yet/ { on = 1 } on && /^## / && !/^## Not supported yet/ { exit } on' "$dl/source/docs/commands/README.md" 2>/dev/null || true)
if [ -n "$unsupported" ]; then
  printf '\n%s\n' "$unsupported" >> "$src/commands/index.md"
else
  sed -i 's#commands/index\.md\#not-supported-yet#commands/index.md#g' "$src"/*.md
fi

# Help of the program's own subcommands and their flags.
cli_help() {
  local args=$1
  echo "## statscraft $args"
  echo
  echo '```text'
  # shellcheck disable=SC2086
  "$bin" $args --help
  echo '```'
  echo
  # shellcheck disable=SC2086
  "$bin" $args --help | sed -n '/^Commands:/,/^$/p' | sed '1d' | awk '{ print $1 }' | { grep -vx -e help -e '' || true; } |
    while read -r sub; do cli_help "$args $sub"; done
}
{
  echo "# Command line help"
  echo
  echo "The output of \`statscraft --help\` and of \`--help\` on every subcommand. [The command line](command-line.md) explains them with examples."
  echo
  echo '```text'
  "$bin" --help
  echo '```'
  echo
  "$bin" --help | sed -n '/^Commands:/,/^$/p' | sed '1d' | awk '{ print $1 }' | { grep -vx -e help -e '' || true; } |
    while read -r sub; do cli_help "$sub"; done
} > "$src/cli.md"

# The version line on top of every page.
note="<p class=\"sc-version\">Statscraft $version, release <a href=\"https://github.com/$repo/releases/tag/$tag\">$tag</a></p>"
while IFS= read -r -d '' f; do
  { echo "$note"; echo; cat "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
done < <(find "$src" -name '*.md' -print0)

# Table of contents: the known guides in reading order, then any other page of docs/ by its title.
title() { sed -n 's/^# //p' "$1" | head -n 1; }
{
  echo "# Summary"
  echo
  echo "[Introduction](index.md)"
  echo
  echo "# Guides"
  echo
  known="getting-started window command-line ai-agents differences"
  for page in $known; do
    if [ -f "$src/$page.md" ]; then echo "- [$(title "$src/$page.md")]($page.md)"; fi
  done
  for f in "$src"/*.md; do
    page=$(basename "$f" .md)
    case " $known index changelog cli SUMMARY " in *" $page "*) continue ;; esac
    echo "- [$(title "$f")]($page.md)"
  done
  echo
  echo "# Reference"
  echo
  echo "- [Commands](commands/index.md)"
  printf '%s' "$summary_cmds"
  echo "- [Command line help](cli.md)"
  echo "- [Changelog](changelog.md)"
} > "$src/SUMMARY.md"

cp -R "$root/assets" "$src/assets"
echo "$tag" > "$src/version.txt"

# The same forbidden-term check as the git hooks, on the assembled pages.
pattern=$(sed -n "s/^PATTERN='\(.*\)'$/\1/p" "$root/.githooks/check-terms")
if grep -rniE "$pattern" "$src"; then echo "forbidden vendor term in the assembled pages" >&2; exit 1; fi

"${MDBOOK:-mdbook}" build "$root"

# Every internal link and #anchor in the site must resolve.
python3 -I - "$out/html" <<'EOF'
import os, re, sys
from urllib.parse import unquote
site = sys.argv[1]
ids, links = {}, []
for d, _, files in os.walk(site):
    for f in files:
        if not f.endswith(".html"):
            continue
        p = os.path.join(d, f)
        text = open(p, encoding="utf-8").read()
        ids[p] = set(re.findall(r'\sid="([^"]+)"', text))
        if f not in ("print.html", "404.html"):  # print.html repeats every page; 404.html links from the site root
            links += [(p, h) for h in re.findall(r'\shref="([^"]*)"', text)]
bad = []
for page, href in links:
    if re.match(r"[a-z][a-z0-9+.-]*:", href) or href.startswith("//"):
        continue  # external
    path, _, anchor = href.partition("#")
    target = os.path.normpath(os.path.join(os.path.dirname(page), unquote(path))) if path else page
    if os.path.isdir(target):
        target = os.path.join(target, "index.html")
    if not os.path.exists(target) or (anchor and target.endswith(".html") and unquote(anchor) not in ids.get(target, ())):
        bad.append(f"{os.path.relpath(page, site)}: {href}")
if bad:
    print("broken internal links:", *sorted(set(bad)), sep="\n  ", file=sys.stderr)
    sys.exit(1)
print(f"checked {len(links)} internal and external links")
EOF
echo "built Statscraft $version documentation in $out/html"

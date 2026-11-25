# Statscraft documentation

The source of [docs.statscraft.org](https://docs.statscraft.org): the documentation of the newest [Statscraft release](https://github.com/statscrafthq/statscraft/releases).

The pages are not written here. `build.sh` assembles them from one release:

- **Copied** from the main repository at the release tag: `docs/*.md` (the guides), `README.md` up to its list of documents (the start page) and `CHANGELOG.md`.
- **Generated** from the release's Linux binary: one page per command from `statscraft help` and `statscraft help COMMAND`, and the command line help from `statscraft --help` and `--help` of every subcommand.
- **Added** on every page: a line naming the release the pages describe.

This repository holds only the build script, the theme (`theme/statscraft.css`, the fonts and the icon in `assets/`) and the workflows.

## Build locally

You need `gh` (signed in), `curl` and the [mdBook](https://github.com/rust-lang/mdBook) binary. mdBook is a build tool under the Mozilla Public License 2.0; it is downloaded for the build and not part of the site's source.

```
MDBOOK=/path/to/mdbook ./build.sh          # the newest release
MDBOOK=/path/to/mdbook ./build.sh v0.1.1   # a given release
```

The site is written to `build/html`. The build fails when a command's help cannot be read or when a page holds a vendor name.

## Translations

The guides and the start page are also published in Simplified Chinese at `/zh-CN/`. Each `po/<language>.po` file gives one more site under `/<language>/`, built with the `gettext` preprocessor of [mdbook-i18n-helpers](https://github.com/google/mdbook-i18n-helpers) (Apache-2.0, a build tool like mdBook; set `MDBOOK_GETTEXT` to its `mdbook-gettext` binary if it is not on PATH). A paragraph the .po file does not translate stays English, so a release that changes the English text never breaks the translated site; the command pages, the command line help and the changelog stay English. `po/glossary-zh-CN.md` holds the terms. `theme/languages.js` lists the languages for the links in the menu bar.

After a release, to translate what changed:

```
./build.sh                                                     # the English pages in build/src
MDBOOK_OUTPUT='{"xgettext": {"pot-file": "messages.pot"}}' mdbook build -d po-new   # po-new/messages.pot
python3 -I po/i18n.py jobs  po-new/messages.pot po/zh-CN.po jobs     # what is not translated yet
# translate jobs/<page>.json into done/<page>.json: {"id": "translation"}
python3 -I po/i18n.py merge po-new/messages.pot po/zh-CN.po jobs done build/src build/html
```

`merge` gives a translated heading the anchor of the English one, so links between pages keep working, and drops messages that are no longer in the pages. A native speaker has not reviewed the Chinese text yet.

## Publishing

The **Docs** workflow builds the site and publishes it to GitHub Pages. It runs every day and rebuilds only when the newest release differs from the one in the live site's `version.txt`. A push to main that changes `po/`, `theme/`, `book.toml` or `build.sh` rebuilds it too. Run it by hand (Actions, Docs, Run workflow, or `gh workflow run pages.yml`) to rebuild in any case.

## Licenses

The fonts in `assets/fonts` are Schibsted Grotesk and JetBrains Mono under the SIL Open Font License; the license texts are next to them. The documentation text is from the main repository, MIT.

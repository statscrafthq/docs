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

## Publishing

The **Docs** workflow builds the site and publishes it to GitHub Pages. It runs every day and rebuilds only when the newest release differs from the one in the live site's `version.txt`. Run it by hand (Actions, Docs, Run workflow, or `gh workflow run pages.yml`) to rebuild in any case.

## Licenses

The fonts in `assets/fonts` are Schibsted Grotesk and JetBrains Mono under the SIL Open Font License; the license texts are next to them. The documentation text is from the main repository, MIT.

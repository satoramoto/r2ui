# Releasing r2ui

Everything happens on `main`; there are no release or develop branches. A release is a `vX.Y.Z` tag on a commit on main. Pushing the tag runs `.github/workflows/publish.yml`, which publishes the gem to RubyGems and creates the GitHub Release.

## Day to day

User-facing changes go under `## Unreleased` at the top of CHANGELOG.md, in the PR that makes them. CI (`ci.yml`, `conformance.yml`) runs on PRs and on pushes to main.

## Cut a release

1. On an up-to-date main, set the version in `lib/r2ui/version.rb` (for example `VERSION = "0.3.0"`).
2. In CHANGELOG.md, rename `## Unreleased` to `## 0.3.0` and add a fresh, empty `## Unreleased` above it.
3. Commit both on main (directly, or through a PR that you merge; the tag must point at a commit that is on main).
4. Tag and push:

   ```sh
   git tag v0.3.0 && git push origin main v0.3.0
   ```

Publish (`.github/workflows/publish.yml`, run in the GitHub environment `release`) then:

- checks the tag is `vX.Y.Z` and that `X.Y.Z` equals `R2UI::VERSION` in `lib/r2ui/version.rb` at the tagged commit;
- checks the tagged commit is on main (an ancestor of `origin/main`);
- checks RubyGems doesn't already have that version (if it does, or RubyGems answers with anything but "found" or "not found", it fails without publishing);
- extracts the `## X.Y.Z` section of CHANGELOG.md as the release notes (fails if it's missing or empty);
- runs `bundle exec rake test`;
- builds `r2ui-X.Y.Z.gem` and pushes it to RubyGems with trusted publishing (a short-lived key from `rubygems/configure-rubygems-credentials`; no API key is stored);
- creates the GitHub Release `vX.Y.Z` titled "r2ui X.Y.Z" with the `.gem` attached and the changelog section as notes.

## When something fails

- **Fails before "Push the gem to RubyGems"** (a check, the tests, the build): nothing is published. If the cause is outside the tagged commit (RubyGems down, a flaky test), re-run the failed job. If the tagged commit itself is wrong, see "Wrong tag" below.
- **Fails after the gem is on RubyGems** (usually "Create the GitHub Release"): re-running stops at the "already on RubyGems" check by design. Finish the GitHub Release by hand from a checkout of the tag:

  ```sh
  git checkout v0.3.0
  gem fetch r2ui -v 0.3.0   # the exact r2ui-0.3.0.gem RubyGems serves
  ruby -e 'v = "0.3.0"; print File.read("CHANGELOG.md")[/^## #{Regexp.escape(v)}[ \t]*\n(.*?)(?=^## |\z)/m, 1].strip, "\n"' > notes.md
  gh release create v0.3.0 r2ui-0.3.0.gem --verify-tag --title "r2ui 0.3.0" --notes-file notes.md
  ```
- **Wrong tag** (wrong commit, version.rb or CHANGELOG not bumped), as long as the gem isn't on RubyGems yet: delete the tag, fix main, and tag again:

  ```sh
  git push origin :refs/tags/v0.3.0 && git tag -d v0.3.0
  # fix and commit on main, then
  git tag v0.3.0 && git push origin main v0.3.0
  ```

  Once a version is on RubyGems it's final: release the fix as the next patch version instead.

## One-time setup (owner)

1. On rubygems.org, r2ui → Trusted publishers → Create: GitHub Actions, repository owner `satoramoto`, repository name `r2ui`, workflow filename `publish.yml`, environment `release`. GitHub creates the `release` environment on the first publish run.
2. Optional: Settings → Environments → `release` → add yourself as a required reviewer, so each publish waits for your approval. You can also limit its deployment refs to tags matching `v*.*.*`.
3. Retro-tag 0.1.0. Every file in the 0.1.0 gem on RubyGems matches commit `048270f` ("gem-push: don't mask op run output…"), the last commit before it was pushed:

   ```sh
   git tag v0.1.0 048270f742265232a661100935fe25b4c9834f13 && git push origin v0.1.0
   ```

   This doesn't run Publish: a tag push runs the workflows in the tagged commit, and `048270f` has no `.github/workflows/`. (If it did run, it would stop at the "already on RubyGems" check without publishing.) Create its GitHub Release by hand if you want one, as in "When something fails".

## Manual fallback

`bin/gem-push` builds the gem and pushes it with a 1Password-backed API key (Touch ID). Use it only if trusted publishing is unavailable: bump and tag as above (Publish then fails at the trusted-publishing step, before pushing anything; or cancel it), run `bin/gem-push` from a checkout of the tag, then create the GitHub Release by hand with the `gh release create` command above.

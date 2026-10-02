# Releasing r2ui

## Branches

r2ui uses git-flow:

- `develop` is the integration branch and the default branch. Feature and fix PRs target it.
- `main` only ever holds released code. Every commit on main that changes the gem is a release, tagged `vX.Y.Z`.
- `release/X.Y.Z` is cut from develop to prepare a release; it merges into main.
- `hotfix/X.Y.Z` is cut from main to patch the latest release; it merges into main.
- After every release, main is merged back into develop.

CI (`ci.yml`, `conformance.yml`) runs on PRs and on pushes to main, develop, `release/**` and `hotfix/**`.

User-facing changes go under `## Unreleased` at the top of CHANGELOG.md, in the PR that makes them.

## Cut a release

1. Actions → **Release** → Run workflow. Leave "Use workflow from" on `develop`, enter the version (for example `0.2.0`, no `v`) and pick `release`.
2. The workflow (`.github/workflows/release.yml`) checks the version is `X.Y.Z`, newer than the latest release on RubyGems and the tags, not already tagged and not already in progress. It then creates `release/X.Y.Z` from develop, sets `lib/r2ui/version.rb`, moves the `## Unreleased` entries under `## X.Y.Z`, opens the PR "Release X.Y.Z" into main and starts CI and conformance on the branch.
3. Review the PR. Push any last fixes to `release/X.Y.Z` (they reach develop through the back-merge).
   The PR is opened with `GITHUB_TOKEN`, which doesn't trigger `pull_request` workflows, so the Release workflow dispatches CI and conformance itself. Their results show on the head commit (commit status / Actions tab), not as `pull_request` checks in the PR's checks list.
4. Merge the PR with **Create a merge commit**. Don't squash or rebase: the main→develop back-merge relies on the release commits being ancestors of main. `.github/workflows/publish.yml` then:
   - checks `version.rb` matches the branch and that RubyGems doesn't already have that version (if it does, it fails without publishing anything);
   - tags the merge commit `vX.Y.Z`;
   - builds the gem and pushes it to RubyGems with trusted publishing (no API key);
   - creates the GitHub Release `vX.Y.Z` with the `.gem` attached and the changelog section as notes;
   - merges main into develop, or opens a "Merge vX.Y.Z back into develop" PR when it can't push (a conflict, usually in CHANGELOG.md, or branch protection on develop).
5. Expect the back-merge PR: develop usually has new `## Unreleased` entries, so CHANGELOG.md conflicts. Resolve it locally: check out develop, `git merge origin/main`, keep develop's `## Unreleased` section above main's `## X.Y.Z` section (dropping entries that moved into `## X.Y.Z`), commit and push to the PR's branch (or straight to develop), then merge the PR with a merge commit.

## Cut a hotfix

1. Actions → **Release** → Run workflow, enter the patch version (for example `0.2.1`) and pick `hotfix`.
2. The workflow creates `hotfix/0.2.1` from main with the version bumped and an empty `## 0.2.1` section, and opens a **draft** PR into main.
3. Push the fix to `hotfix/0.2.1`, with its entry under `## 0.2.1` in CHANGELOG.md. Mark the PR ready and merge it with **Create a merge commit**; publishing runs as for a release. Publishing fails if the `## 0.2.1` section is empty.

## When something fails

- Release fails before pushing anything: fix the cause and run it again.
- Publish fails before "Push the gem to RubyGems": re-run the failed job; the tag step accepts a tag already on the same commit.
- Publish fails after the gem is on RubyGems: re-running stops at the "already on RubyGems" check by design. Finish by hand: `gh release create vX.Y.Z r2ui-X.Y.Z.gem --verify-tag --notes-file <notes>` and merge main into develop.

## One-time setup (owner)

1. Create `develop` from main: `git push origin origin/main:refs/heads/develop`.
2. Settings → General → Default branch: `develop`.
3. Settings → Actions → General → Workflow permissions: allow GitHub Actions to create and approve pull requests (the Release workflow opens the PR, Publish may open the back-merge PR). Read and write permissions are not needed as the default; the workflows ask for them.
4. On rubygems.org, r2ui → Trusted publishers → Create: GitHub Actions, repository owner `satoramoto`, repository name `r2ui`, workflow filename `publish.yml`, environment `release`. Publish runs in the GitHub environment `release`; GitHub creates it on first use, and you can add required reviewers to it to approve each publish.
   Don't restrict the `release` environment's deployment branches to `main`: Publish runs on the PR-closed event, whose ref is `refs/pull/N/merge`.
5. Retro-tag 0.1.0. Every file in the 0.1.0 gem on RubyGems matches commit `048270f` ("gem-push: don't mask op run output…"), the last commit before it was pushed: `git tag v0.1.0 048270f742265232a661100935fe25b4c9834f13 && git push origin v0.1.0`.
6. Optional: protect `main` (require PRs and CI). Publish only pushes the tag and touches develop, so it works with main protected. If develop is protected against direct pushes, the back-merge arrives as a PR instead.

`bin/gem-push` (1Password-backed `gem push`) stays as a manual fallback; with trusted publishing set up you shouldn't need it.

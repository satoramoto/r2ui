# Build station

You make one work order's acceptance checks pass, as one small PR.

- Work in your own worktree on the branch you're given (it may already hold the spec station's tests). Create it with `git checkout --no-track -b <branch> origin/<base>` if it doesn't exist; push with `git push -u origin HEAD:refs/heads/<branch>`.
- Touch the fewest files you can. Prefer adding a new file over editing a shared one; if you must edit a file other work orders are likely to touch (`lib/r2ui.rb`, `lib/r2ui/app.rb`, AGENTS.md), keep the edit to a few lines so merges stay clean.
- Make every file change with the Edit and Write tools, never sed, heredocs or one-off scripts, even when auto mode would allow it (the owner's CLAUDE.md rule; s26 broke it).
- Never run git or cd into the main checkout (`/Users/ryan/The Source/r2ui`); work only in your order's worktree.
- Don't edit acceptance checks to make them pass. If a check is wrong, say so in your result.
- There is no lint command (rubocop isn't in the bundle); don't try to run it and don't report it. If `bundle exec` fails on a missing gem, use `ruby -Itest -Ilib <file>` and let CI run the bundle; report it only if a test can't run at all.
- The missing review bot account is already known to the owner; don't report it in `problems`.
- Build only on what is on `main`. If your order needs a keyword or hook from another order that hasn't merged yet (e.g. `state` before s05 merged), don't use it in code, tests or docs examples; work around it and name the dependency in the PR body.
- If the core doesn't expose something you need (e.g. table rects for mouse hit-testing), don't copy core logic into the extension silently: report it as a needed contract change in `problems`, and keep any stopgap small and marked in the PR body.
- Run the targeted tests for what you touched, and `bin/conformance check --ratchet` if you touched `lib/r2ui/compat/`. Don't run anything twice.
- Open the PR against `main` with a short body: what, why, decisions, what you ran. End it with the attribution lines from your instructions.
- Don't merge your own PR at this station. Merging is integrate's job, after inspect; merging at build skips inspection.
- On rework: fix only what the inspection or integration notes say, push to the same branch.

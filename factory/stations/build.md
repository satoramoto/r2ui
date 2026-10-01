# Build station

You make one work order's acceptance checks pass, as one small PR.

- Work in your own worktree on the branch you're given (it may already hold the spec station's tests). Create it with `git checkout --no-track -b <branch> origin/<base>` if it doesn't exist; push with `git push -u origin HEAD:refs/heads/<branch>`.
- Touch the fewest files you can. Prefer adding a new file over editing a shared one; if you must edit a file other work orders are likely to touch (`lib/r2ui.rb`, `lib/r2ui/app.rb`, AGENTS.md), keep the edit to a few lines so merges stay clean.
- Don't edit acceptance checks to make them pass. If a check is wrong, say so in your result.
- Run the targeted tests for what you touched, and `bin/conformance check --ratchet` if you touched `lib/r2ui/compat/`. Don't run anything twice.
- Open the PR against `main` with a short body: what, why, decisions, what you ran. End it with the attribution lines from your instructions.
- On rework: fix only what the inspection or integration notes say, push to the same branch.

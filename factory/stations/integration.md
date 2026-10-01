# Integration station

Every few ready orders, you check that their branches work **together**: each PR passed on its own, but parts can still clash once assembled (s03's module named `Keys` hid the core `R2UI::Keys` and broke 86 tests only after all stories merged).

- Use the local integration worktree you're given. Reset it to `origin/main` (`git fetch` then `git reset --hard origin/main`; it is never pushed), then `git merge --no-edit origin/<branch>` for each branch in order.
- A merge conflict: abort that merge, record the branch and the conflicting files, continue with the rest.
- Run `bundle exec rake test` once on the result (pass/fail is the exit code; cap output).
- For each failure, find which branch's change causes it (the failing test's file, the backtrace, `git log` on the lines involved). Blame a branch only when you can point at the cause; otherwise report it unattributed.
- Don't fix anything and don't push. Report culprits with a one-line problem each, phrased as rework notes for that order's build station.

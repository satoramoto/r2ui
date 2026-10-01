# Integrate station

You get one inspected PR onto `main`.

- Wait for CI with `gh pr checks <n> --watch` (one call; no sleep loops).
- Before merging, check `gh pr view <n> --json reviewDecision`. If it isn't `APPROVED`, don't call `gh pr merge` (the classifier refuses it as "Merge Without Review"); report `blocked`: CI state, PR number, and "needs an approving review or the owner's merge".
- Green, approved and mergeable: `gh pr merge <n> --merge`, then remove the build's worktree and local branch (`git worktree remove <path>`, `git branch -D <branch>`) and report merged.
- Merge conflict or out of date: report `rework` with what conflicts; don't resolve it yourself.
- Merge refused by a permission check (for example the classifier's "Merge Without Review") or any other non-code reason with green CI: report `blocked` with the PR number and what the owner must do. Do NOT report `rework`; build can't fix permissions. Don't retry or work around the denial.
- Red CI: report `rework` with the failing check and the relevant log lines (`gh run view <id> --log-failed`, trimmed).

# Integrate station

You get one inspected PR onto `main`.

- Wait for CI with `gh pr checks <n> --watch` (one call; no sleep loops).
- Green and mergeable: `gh pr merge <n> --merge`, then remove the build's worktree and local branch (`git worktree remove <path>`, `git branch -D <branch>`) and report merged.
- Merge conflict or out of date: report `rework` with what conflicts; don't resolve it yourself.
- Red CI: report `rework` with the failing check and the relevant log lines (`gh run view <id> --log-failed`, trimmed).

# Git Migration Notes

## 2026-05-03 Parent Main Attribution Rewrite

The parent repository `main` branch was rewritten on 2026-05-03 to remove
assistant co-author trailers from historical commit messages. This was an
attribution-only rewrite: the old and new branch tips have the same tree hash,
so tracked file content did not change as part of the rewrite.

| Item | SHA |
|---|---|
| Old `main` tip before rewrite | `cdf278a0f382a0bc25f2c3bb6ca2e5041321d720` |
| New `main` tip after rewrite | `f6c98fe9fb91cfbf4351a2d04fd812b5e7a83068` |
| Tree hash at both tips | `fb0c9fe65021f7507c27e2a32a57cd645a10403d` |
| Local backup ref | `backup/pre-claude-trailer-rewrite-20260503-131204` |

The rewritten commit messages removed lines matching:

```text
Co-Authored-By: Claude ... <noreply@anthropic.com>
```

## Updating Local Checkouts

For a checkout with no local work to keep:

```bash
git fetch origin
git reset --hard origin/main
```

For a checkout with local work:

```bash
git status
git stash push -u -m pre-main-attribution-rewrite
git fetch origin
git reset --hard origin/main
git stash pop
```

If a local branch was based on the old parent `main`, rebase it onto the new
`origin/main` after fetching:

```bash
git fetch origin
git rebase --rebase-merges origin/main
```

## Notes

- The canonical parent remote is `https://github.com/yifeng-ethz/mu3e-ip-cores.git`.
- The rewrite was limited to parent repository commit messages.
- Submodule repositories were not rewritten by this migration.
- GitHub repository graphs may take time to recalculate after the force-push.

## 2026-05-04 Main Branch Verification

The parent `main` branch was rechecked after the rewrite:

| Item | SHA |
|---|---|
| Verified local `main` tip | `0f034468c9bd83d8fcf47020bf295658554d33d6` |
| Verified `origin/main` tip | `0f034468c9bd83d8fcf47020bf295658554d33d6` |
| Verified tree hash at both tips | `848f8b372f792b45b607b66e6be1bac29bd703ee` |
| Post-rewrite base confirmed as ancestor | `f6c98fe9fb91cfbf4351a2d04fd812b5e7a83068` |

Verification commands run on 2026-05-04:

```bash
git fetch origin --prune
git merge-base --is-ancestor f6c98fe9fb91cfbf4351a2d04fd812b5e7a83068 main
git log --format='%H%n%B%n---END---' main -- | rg -i 'Co-Authored-By: Claude|anthropic'
```

The local and remote `main` tips matched, the post-rewrite base was an ancestor
of `main`, and the trailer scan returned no matches.

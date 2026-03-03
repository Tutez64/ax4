# GitHub wiki and `docs/` sync

## How GitHub wiki works

GitHub Wiki is a separate Git repository:

- Main repo: `<repo>.git`
- Wiki repo: `<repo>.wiki.git`

By default there is no automatic link between files in the main repository and files in the Wiki repository.

## Recommended model

Use `docs/` in the main repository as source of truth:

- versioned in normal PR flow
- reviewed with code changes
- easy to keep in sync with implementation

Then optionally sync `docs/*.md` to Wiki pages with CI.

Important:

- To modify Wiki content, edit files in `docs/` in the main repository.
- Direct edits in the GitHub Wiki are not persistent and can be overwritten by the next sync.

## Included workflow

This repository includes `.github/workflows/wiki-sync.yml`.

Behavior:

1. Trigger on push to `master` when `docs/**` changes, or manually (`workflow_dispatch`)
2. Clone `<repo>.wiki.git`
3. Copy `docs/*.md` to wiki root
4. Ensure `Home.md` exists in wiki (`docs/Home.md`)
5. Commit and push changes only when needed

Sync direction is one-way: `docs/` -> Wiki.

## Requirements

- GitHub Actions enabled
- Repository wiki enabled in GitHub settings
- Default `GITHUB_TOKEN` permissions sufficient for wiki push

## Manual alternative

If you prefer manual updates:

```bash
git clone https://github.com/<owner>/<repo>.wiki.git
```

Edit wiki pages directly and push.

For most projects, automated one-way sync from `docs/` is easier to maintain.

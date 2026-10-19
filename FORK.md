# Personal fork workflow

This fork tracks [pctrade/end4-pC](https://github.com/pctrade/end4-pC) and adds an
OpenCode desktop integration.

## Branches

| Branch | Purpose |
| --- | --- |
| `main` | Mirror of `upstream/main`. Never commit here. |
| `personal` | Integration branch with personal changes. |
| `feat/*` | Short-lived feature branches, merged into `personal`. |

## Remotes

```text
origin    https://github.com/zxmbrxnx/end4-pC.git
upstream  https://github.com/pctrade/end4-pC.git
```

`main` tracks `upstream/main`; `git push` sends it to `origin/main`.
`personal` tracks `origin/personal`.

## Sync upstream

```bash
git fetch upstream --prune
git switch main
git pull --ff-only
git push
git switch personal
git merge main
git push
```

Check what changed before merging:

```bash
git log --oneline main..upstream/main
git diff --stat main..upstream/main
```

If the merge is clean, done. If there are conflicts, resolve them on `personal`.
Prefer taking the upstream version of a file and re-applying the small local
hooks listed below.

## Feature workflow

```bash
git switch -c feat/my-feature personal
# work, commit
git switch personal
git merge --no-ff feat/my-feature
git push
git branch -d feat/my-feature
```

## Upstream files with local hooks

Keep these changes small and isolated. Everything else should live in new files.

| File | Change |
| --- | --- |
| `services/DesktopWidgets.qml` | catalog entry |
| `modules/common/Config.qml` | `background.widgets.opencodeHub` and `bar.opencode` blocks |
| `modules/ii/background/WidgetsLoader.qml` | import, model entry, component |
| `modules/ii/bar/DynamicIsland.qml` | OpenCode alert provider and component |
| `modules/ii/settings/pages/BarConfig.qml` | bar widget entry |
| `modules/ii/settings/DashboardBarWidgets.qml` | bar widget entry |
| `services/SettingsPages.qml` | settings page entry |
| `translations/en_US.json`, `translations/es_ES.json` | optional new keys |
| `.gitignore` | ignore Python cache files |

New code lives in:

```text
services/OpenCode.qml
scripts/ai/opencode-bridge.py
scripts/ai/opencode-mock-server.py
modules/ii/background/widgets/opencode/
modules/ii/bar/Opencode.qml
modules/ii/bar/OpenCodePopup.qml
modules/ii/bar/DiOpenCode.qml
modules/ii/settings/pages/OpenCodeConfig.qml
```

## Conflict strategy

- Keep local edits in upstream files to a few lines.
- If a hook file conflicts, take the upstream version and re-apply the local block.
- `git config rerere.enabled true` is enabled in this clone.
- Create a checkpoint before syncing:

```bash
git tag pre-sync-$(date +%F)
git push origin pre-sync-$(date +%F)
```

## Testing

```bash
qs -c end4-pC
```

Check the desktop widget catalog, the bar widget list, and the settings page after
each upstream merge.

## Notes

- Do not commit secrets or local OpenCode state.
- Keep the upstream license and attribution.

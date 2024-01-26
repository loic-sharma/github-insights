# GitHub Insights

Find trending GitHub issues.

## Trending issues report

Find the Flutter issues with the most reactions in the last 6 weeks:

```sql
SELECT
  repository || '#' || id AS id,
  any_value(title) AS title,
  list(reactions) AS reactions,
  max(reactions) - min(reactions) AS delta_reactions
FROM 'top_issues/flutter/flutter/*.jsonl'
WHERE date_diff('day', "date", today()) <= 42
GROUP BY repository, id
ORDER BY delta_reactions desc;
```

Example results:

| id             | title                                                                                               | delta_reactions |
| -------------- | --------------------------------------------------------------------------------------------------- | --------------- |
| flutter#94340  | [Feature Request] Support for Jetbrains Fleet\n                                                     |               5 |
| flutter#126005 | ?? Add Swift Package Manager compatibility                                                          |               5 |
| flutter#41722  | Implement PlatformView support on macOS                                                             |               4 |
| flutter#128313 | Add support for visionOS                                                                            |               3 |
| flutter#115912 | Support tone-based surface and surface container `ColorScheme` roles                                |               3 |
| flutter#58997  | InteractiveViewer `constrained: false` custom default scale                                         |               2 |
| flutter#52207  | ListView: Poor performance with many variable-extent items + jumpTo (scroll bar, trackpad, mouse .  |               2 |
| flutter#132735 | [Impeller] Blur performance issue.                                                                  |               2 |
| flutter#37777  | Support 32-bit Windows as a target                                                                  |               2 |
| flutter#64491  | Colorized console output does not work in iOS builds but works for Android builds                   |               2 |
| flutter#138614 | Preserve WillPopScope as an alternate for PopScope                                                  |               2 |
| flutter#14330  | Code Push / Hot Update / out of band updates                                                        |               1 |
| flutter#18443  | Support soft hyphenation (line breaks at U+00AD plus rendering a hyphen at the end of the line)     |               1 |
| flutter#19941  | Return index of the first visible item in ListView                                                  |               1 |
| flutter#32120  | Add option to smoothly animate stepped mouse scroll deltas                                          |               1 |
| flutter#65504  | Ctrl+F support, finding text on a page (even when scrolled off screen)                              |               1 |
| flutter#101479 | Move the material and cupertino packages outside of Flutter                                         |               1 |
| flutter#9688   | Input validator async                                                                               |               1 |
| flutter#76248  | [web] Emojis take a few seconds to render on canvaskit                                              |               1 |
| flutter#69676  | Persistent bottom sheet does not respect SafeArea                                                   |               1 |

## Tables

### Top issues

Path: `top_issues/<organization>/<repository name>/<bucket>.jsonl`

Column name | Data type | Description
-- | -- | --
date | string | Date in `YYYY-MM-DD` format
repository | string | Full repository name in `organization/name` format
id | int | GitHub issue number
title | string | GitHub issue title
state | enum | GitHub issue state (`OPEN`, `CLOSED`)
comments | int | Number of GitHub issue comments at this date
participants | int | Number of GitHub users participating in the issue conversation at this date
reactions | int | Number of reactions on the GitHub issue at this date
createdAt | timestamp | When the GitHub issue was created

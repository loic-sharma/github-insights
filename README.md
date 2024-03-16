# GitHub Insights

Find trending GitHub issues.

## Issue delta reports

Find how many new reactions and comments each issue received each day:

```sql
.mode json
.output issue_deltas_daily.json

WITH
  issues AS (
    SELECT
      "date",
      repository || '#' || id  AS issue_id,
      title,
      reactions,
      comments,
      'https://github.com/' || repository || '/issues/' || id AS issue_url,
    FROM 'top_issues/flutter/flutter/*.jsonl'
  ),
  issue_deltas_daily AS (
    SELECT
      "date",
      issue_id,
      reactions - LAG(reactions) OVER (PARTITION BY issue_id ORDER BY date) AS new_reactions,
      comments - LAG(comments) OVER (PARTITION BY issue_id ORDER BY date) AS new_comments,
      title,
      issue_url,
    FROM issues
    ORDER BY "date" DESC, new_reactions DESC
  )
SELECT
  *
FROM issue_deltas_daily
WHERE new_reactions != 0
;
```

Find how many new reactions and comments each issue received each week:

```sql
.mode csv
.output issue_deltas_weekly.csv

WITH
  issues AS (
    SELECT
      "date",
      repository || '#' || id  AS issue_id,
      title,
      reactions,
      comments,
      'https://github.com/' || repository || '/issues/' || id AS issue_url,
    FROM 'top_issues/flutter/flutter/*.jsonl'
  ),
  issue_deltas_daily AS (
    SELECT
      "date",
      issue_id,
      reactions - LAG(reactions) OVER (PARTITION BY issue_id ORDER BY date) AS new_reactions,
      comments - LAG(comments) OVER (PARTITION BY issue_id ORDER BY date) AS new_comments,
      title,
      issue_url,
    FROM issues
    ORDER BY "date" DESC, new_reactions DESC
  )
SELECT
  date_trunc('yearweek', "date") AS "date",
  issue_id,
  SUM(new_reactions) AS new_reactions,
  SUM(new_comments) AS new_comments,
  title,
  issue_url
FROM issue_deltas_daily
WHERE new_reactions != 0 OR new_comments != 0
GROUP BY date_trunc('yearweek', "date"), issue_id, title, issue_url
ORDER BY "date" DESC, new_reactions DESC
;
```

Find the Flutter issues with the most reactions in the last 6 weeks:

```sql
.mode csv
.output issue_deltas_total.csv

SELECT
  repository || '#' || id  AS issue_id,
  any_value(title) AS title,
  min(date) AS start,
  max(date) AS end,
  max(reactions) AS total_reactions,
  max(comments) AS total_comments,
  max(reactions) - min(reactions) AS new_reactions,
  max(comments) - min(comments) AS new_comments,
  'https://github.com/' || repository || '/issues/' || id AS issue_url,
FROM 'top_issues/flutter/flutter/*.jsonl'
WHERE
  date_diff('day', "date", today()) <= 42
GROUP BY repository, issue_id, id
HAVING new_reactions > 0 OR new_comments > 0
ORDER BY new_reactions DESC
;
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

### Dashboard

```sql
.mode json
.output issue_deltas_daily.js

WITH
  issues AS (
    SELECT
      "date",
      repository || '#' || id  AS issue_id,
      title,
      reactions,
      comments,
      'https://github.com/' || repository || '/issues/' || id AS issue_url,
    FROM 'top_issues/flutter/flutter/*.jsonl'
  ),
  issue_deltas_daily AS (
    SELECT
      "date",
      issue_id,
      reactions - LAG(reactions) OVER (PARTITION BY issue_id ORDER BY date) AS new_reactions,
      comments - LAG(comments) OVER (PARTITION BY issue_id ORDER BY date) AS new_comments,
      title,
      issue_url,
    FROM issues
    ORDER BY "date" DESC, new_reactions DESC
  )
SELECT
  *
FROM issue_deltas_daily
WHERE new_reactions != 0;

.output issue_deltas_weekly.js

WITH
  issues AS (
    SELECT
      "date",
      repository || '#' || id  AS issue_id,
      title,
      reactions,
      comments,
      'https://github.com/' || repository || '/issues/' || id AS issue_url,
    FROM 'top_issues/flutter/flutter/*.jsonl'
  ),
  issue_deltas_daily AS (
    SELECT
      "date",
      issue_id,
      reactions - LAG(reactions) OVER (PARTITION BY issue_id ORDER BY date) AS new_reactions,
      comments - LAG(comments) OVER (PARTITION BY issue_id ORDER BY date) AS new_comments,
      title,
      issue_url,
    FROM issues
    ORDER BY "date" DESC, new_reactions DESC
  )
SELECT
  date_trunc('yearweek', "date") AS "date",
  issue_id,
  SUM(new_reactions) AS new_reactions,
  SUM(new_comments) AS new_comments,
  title,
  issue_url
FROM issue_deltas_daily
WHERE new_reactions != 0
GROUP BY date_trunc('yearweek', "date"), issue_id, title, issue_url
ORDER BY "date" DESC, new_reactions DESC
;
```

Edit `issue_deltas_daily`, prepend content with:

```js
var issue_deltas_daily = 
```

Edit `issue_deltas_weekly`, prepend content with:

```js
var issue_deltas_weekly = 
```

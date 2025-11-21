# How to analyze this data yourself

1. Install [DuckDB](https://duckdb.org/).

1. Download the data.

   ```sh
   git clone https://github.com/loic-sharma/github-insights.git
   ```

1. Launch DuckDB.

   ```sh
   cd github-insights
   ```

   ```sh
   duckdb
   ```

1. Run an [example SQL query](#issue-delta-reports)!

> [!TIP]
> Use `git pull` once a day to get the latest data!

## Find how many reactions and comments an issue had in the last 100 days

Find how many reactions and comments https://github.com/flutter/flutter/issues/158050 received in the last 100 days:

```sql
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
  date_diff('day', "date", today()) <= 100 AND
  issue_id = 'flutter/flutter#158050' -- Edit this to your issue ID!
GROUP BY repository, issue_id, id
HAVING new_reactions > 0 OR new_comments > 0
ORDER BY new_reactions DESC
;
```

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

Find the desktop issues with the most reactions in the last 6 weeks:

```sql
WITH
  top_issues AS (
    SELECT
      *,
      repository || '#' || id  AS issue_id,
    FROM read_json(
      'top_issues/**/*.jsonl',
      format = 'newline_delimited',
      columns = {
        date: 'TIMESTAMP',
        repository: 'VARCHAR',
        id: 'BIGINT',
        title: 'VARCHAR',
        state: 'VARCHAR',
        comments: 'BIGINT',
        participants: 'BIGINT',
        reactions: 'BIGINT',
        createdAt: 'TIMESTAMP',
        labels: 'VARCHAR[]'
      }
    )
  ),
  latest_issues AS (
    SELECT * FROM top_issues WHERE date IN (
      SELECT date FROM top_issues ORDER BY date DESC LIMIT 1
    )
  ),
  desktop_issues AS (
    SELECT issue_id FROM latest_issues WHERE list_contains(labels, 'team-desktop')
  )
SELECT
  top_issues.issue_id,
  any_value(title) AS title,
  min(date) AS start,
  max(date) AS end,
  max(reactions) AS total_reactions,
  max(comments) AS total_comments,
  max(reactions) - min(reactions) AS new_reactions,
  max(comments) - min(comments) AS new_comments,
  'https://github.com/' || repository || '/issues/' || id AS issue_url,
FROM top_issues
JOIN desktop_issues ON top_issues.issue_id = desktop_issues.issue_id
WHERE date_diff('day', "date", today()) <= 42
GROUP BY top_issues.issue_id, repository, id
ORDER BY new_reactions DESC;
```

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

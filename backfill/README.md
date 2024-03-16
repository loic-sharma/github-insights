# Issue backfill data

Contains a GitHub issue's daily snapshots.

Path: `backfill/<organization>/<repository name>/<issue number>.jsonl`

### Creating backfill data

To backfill https://github.com/flutter/flutter/issues/123's data until
January 24, 2024:

```
dart --enable-asserts .\bin\github_insights.dart backfill --repository flutter/flutter --issue 123 --until 2024-01-24 --output backfill\flutter\flutter\123.jsonl
```

### Table

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
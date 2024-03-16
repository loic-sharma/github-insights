### Issue backfill data

Contains a GitHub issue's daily snapshots.

Path: `backfill/<organization>/<repository name>/<issue number>.jsonl`

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
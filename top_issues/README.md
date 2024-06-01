### Top issues

Contains daily snapshots of a repository's top issues.

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
labels | undefined or array of strings | The GitHub issue's labels at this date, lowercased.<br>Undefined if this snapshot was captured before labels were supported.

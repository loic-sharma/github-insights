import 'dart:collection';

import 'package:github_insights/github.dart' as github;
import 'package:github_insights/output.dart' as output;
import 'package:intl/intl.dart' as intl;


Future<List<output.IssueSnapshot>> loadTopIssues(
  String? token,
  String repository,
  int limit,
) async {
  var issues = <github.Issue>[];

  String? after;
  bool hasNextPage = false;
  do {
    final result = await github.loadTopIssues(token, repository, after);
    issues.addAll(result.issues);
    after = result.endCursor;
    hasNextPage = result.hasNextPage;
  } while (issues.length < limit && hasNextPage);

  // Sort descending by reactions then by issue number.
  issues.sort((a, b) => compareIssuesByReactionsThenNumber(b, a));

  final timestamp = DateTime.timestamp();
  final today = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);

  return issues
    .take(limit)
    .map((issue) => output.IssueSnapshot(
      date: today,
      repository: repository,
      id: issue.number,
      title: issue.title,
      state: issue.state,
      comments: issue.comments,
      participants: issue.participants,
      reactions: issue.reactions,
      createdAt: issue.createdAt,
      labels: issue.labels,
    ))
    .toList();
}

Future<List<github.TimelineEvent>> loadTimeline(
  String? token,
  String owner,
  String repository,
  int issue,
) async {
  var timeline = <github.TimelineEvent>[];

  var page = 1;
  var hasNextPage = false;
  do {
    final result = await github.loadTimeline(token, owner, repository, issue, page: page);

    timeline.addAll(
      result.events.where((event) => event.createdAt != null)
    );

    hasNextPage = result.links.next != null;
    page++;
  } while (hasNextPage);

  timeline.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

  return timeline;
}

Future<List<github.ReactionEvent>> loadReactions(
  String? token,
  String owner,
  String repository,
  int issue,
) async {
  var reactions = <github.ReactionEvent>[];

  var page = 1;
  var hasNextPage = false;
  do {
    final result = await github.loadReactions(token, owner, repository, issue, page: page);

    reactions.addAll(result.events);

    hasNextPage = result.links.next != null;
    page++;
  } while (hasNextPage);

  reactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  return reactions;
}

List<output.IssueSnapshot> createSnapshots(
  String repository,
  github.Issue issue,
  List<github.TimelineEvent> timeline,
  List<github.ReactionEvent> reactions,
  DateTime cutoff,
) {
  final snapshots = <output.IssueSnapshot>[];

  final today = DateTime.timestamp();

  var timelineIndex = 0;
  var reactionIndex = 0;

  assert(issue.createdAt.isUtc);
  var snapshotDate = DateTime.utc(
    issue.createdAt.year,
    issue.createdAt.month,
    issue.createdAt.day,
  );
  var snapshotState = 'OPEN';
  var snapshotComments = 0;
  var snapshotParticipants = <String>{};
  var snapshotReactions = 0;

  // TODO: Add label data to backfilled information. The timeline API gives us
  // the label's data at that point in time. This information might be stale
  // if a label was renamed or deleted. Backfill data will need to load label
  // IDs and then use that to load label names.
  List<String>? labels;

  while (snapshotDate.isBefore(today)) {
    // Add timeline events to the snapshot state.
    while (timelineIndex < timeline.length) {
      final event = timeline[timelineIndex];
      if (!_sameDay(event.createdAt!, snapshotDate)) {
        break;
      }

      if (event.event == 'commented') {
        snapshotComments++;
        snapshotParticipants.add(event.actorLogin.toLowerCase());
      } else if (event.event == 'closed') {
        snapshotState = 'CLOSED';
      } else if (event.event == 'reopened') {
        snapshotState = 'OPEN';
      }

      timelineIndex++;
    }

    // Add reaction events to the snapshot state.
    while (reactionIndex < reactions.length) {
      final reaction = reactions[reactionIndex];
      if (!_sameDay(reaction.createdAt, snapshotDate)) {
        break;
      }

      snapshotReactions++;
      reactionIndex++;
    }

    snapshots.add(output.IssueSnapshot(
      date: snapshotDate,
      repository: repository,
      id: issue.number,
      title: issue.title,
      state: snapshotState,
      comments: snapshotComments,
      participants: snapshotParticipants.length,
      reactions: snapshotReactions,
      createdAt: issue.createdAt,
      labels: labels,
    ));

    snapshotDate = snapshotDate.add(const Duration(days: 1));
  }

  assert(issue.state == snapshotState);
  assert(issue.comments == snapshotComments);
  // GitHub seems to include more than folks that comment...
  // assert(issue.participants == snapshotParticipants.length);
  assert(issue.reactions == snapshotReactions);

  return snapshots
    .where((snapshot) => snapshot.date.isBefore(cutoff))
    .toList();
}

final _repositoryRegex = RegExp(r'^[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+$');
bool validRepository(String repository) => _repositoryRegex.hasMatch(repository);
void validateRepository(String repository) {
  if (!validRepository(repository)) {
    throw 'Invalid repository $repository. Expected format is owner/repo.';
  }
}

bool _sameDay(DateTime a, DateTime b) {
  assert(a.isUtc == b.isUtc);

  if (a.year != b.year) return false;
  if (a.month != b.month) return false;
  if (a.day != b.day) return false;

  return true;
}

int compareIssuesByReactionsThenNumber(github.Issue a, github.Issue b) {
  final reactionsComparison = a.reactions.compareTo(b.reactions);
  if (reactionsComparison != 0) {
    return reactionsComparison;
  }

  return a.number.compareTo(b.number);
}

intl.DateFormat _deltaBucketFormatter = intl.DateFormat('MMM d');

class _IssueDeltaBuilder {
  output.IssueSnapshot? _earliest;
  output.IssueSnapshot? _latest;

  // SplayTreeMap to iterate by key order.
  final Map<DateTime, _IssueDeltaBucketBuilder> _buckets
   = SplayTreeMap<DateTime, _IssueDeltaBucketBuilder>();

  void add(output.IssueSnapshot snapshot) {
    if (_earliest == null || snapshot.date.isBefore(_earliest!.date)) {
      _earliest = snapshot;
    }

    if (_latest == null || snapshot.date.isAfter(_latest!.date)) {
      _latest = snapshot;
    }

    final bucketKey = startOfWeekUtc(snapshot.date);
    if (!_buckets.containsKey(bucketKey)) {
      _buckets[bucketKey] = _IssueDeltaBucketBuilder();
    }

    _buckets[bucketKey]!.add(snapshot);
  }

  output.IssueDelta build(DateTime start, DateTime end) {
    final buckets = <String>[];
    final values = <int>[];
    var lastValue = 0;

    final week = Duration(days: 7);
    for (var bucket = startOfWeekUtc(start); bucket.isBefore(end); bucket = bucket.add(week)) {
      final bucketName = _deltaBucketFormatter.format(bucket);
      final value = _buckets[bucket]?.build(start, end) ?? lastValue;

      buckets.add(bucketName);
      values.add(value);
      lastValue = value;
    }

    var recentReactions = (_isDateTimeBetween(_latest!.createdAt, start, end))
      ? _latest!.reactions
      : _latest!.reactions - _earliest!.reactions;

    return output.IssueDelta(
      id: _latest!.id,
      repository: _latest!.repository,
      name: _latest!.title,
      url: Uri.parse('https://github.com/${_latest!.repository}/issues/${_latest!.id}'),
      labels: _latest!.labels ?? const <String>[],
      totalReactions: _latest!.reactions,
      recentReactions: recentReactions,
      buckets: buckets,
      values: values,
    );
  }
}

class _IssueDeltaBucketBuilder {
  DateTime _start = DateTime.utc(9999);
  DateTime _end = DateTime.utc(0);

  DateTime? _createdAt;
  int _reactionsStart = -1;
  int _reactionsEnd = -1;

  void add(output.IssueSnapshot snapshot) {
    _createdAt = snapshot.createdAt;

    if (snapshot.date.isBefore(_start)) {
      _start = snapshot.date;
      _reactionsStart = snapshot.reactions;
    }

    if (snapshot.date.isAfter(_end)) {
      _end = snapshot.date;
      _reactionsEnd = snapshot.reactions;
    }
  }

  int build(DateTime start, DateTime end) {
    assert(_createdAt != null && _reactionsStart != -1 && _reactionsEnd != -1);

    return _reactionsEnd;
  }
}

List<output.IssueDelta> calculateIssueDeltas(
  List<output.IssueSnapshot> snapshots,
  DateTime start, // inclusive
  DateTime end, // exclusive
) {
  snapshots = snapshots
    .where((snapshot) => _isDateTimeBetween(snapshot.date, start, end))
    .toList();

  final deltaBuilders = <String, _IssueDeltaBuilder>{};

  for (final snapshot in snapshots) {
    final issueKey = '${snapshot.repository}#${snapshot.id}';

    if (!deltaBuilders.containsKey(issueKey)) {
      deltaBuilders[issueKey] = _IssueDeltaBuilder();
    }

    deltaBuilders[issueKey]!.add(snapshot);
  }

  return deltaBuilders.values.map((b) => b.build(start, end)).toList();
}

bool _isDateTimeBetween(
  DateTime date,
  DateTime startInclusive,
  DateTime endExclusive,
) {
  assert(startInclusive.isBefore(endExclusive));

  if (date.isBefore(startInclusive)) return false;
  if (date.isAfter(endExclusive)) return false;
  if (date == endExclusive) return false;

  return true;
}

DateTime startOfWeekUtc(DateTime date) {
  assert(date.isUtc);

  final start = date.subtract(Duration(days: date.weekday - 1));

  return DateTime.utc(start.year, start.month, start.day);
}

DateTime endOfWeekUtc(DateTime date) {
  assert(date.isUtc);

  final end = date.add(Duration(days: 7 - date.weekday));

  return DateTime.utc(end.year, end.month, end.day);
}

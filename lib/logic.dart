import 'package:github_insights/github.dart' as github;
import 'package:github_insights/output.dart' as output;


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
      today,
      repository,
      issue.number,
      issue.title,
      issue.state,
      issue.comments,
      issue.participants,
      issue.reactions,
      issue.createdAt,
      issue.labels,
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

  final kinds = <String, Set<String>>{};

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
      snapshotDate,
      repository,
      issue.number,
      issue.title,
      snapshotState,
      snapshotComments,
      snapshotParticipants.length,
      snapshotReactions,
      issue.createdAt,
      labels,
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

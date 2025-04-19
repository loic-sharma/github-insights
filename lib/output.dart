import 'dart:io';
import 'dart:convert';

import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as path;

import 'package:github_insights/logic.dart';

final dayFormat = intl.DateFormat('yyyy-MM-dd');

class IssueSnapshot {
  IssueSnapshot({
    required this.date,
    required this.repository,
    required this.id,
    required this.title,
    required this.state,
    required this.comments,
    required this.participants,
    required this.reactions,
    required this.createdAt,
    required this.labels,
  }) : assert(date.isUtc),
      assert(validRepository(repository)),
      assert(state == 'OPEN' || state == 'CLOSED'),
      assert(comments >= 0),
      assert(participants >= 0),
      assert(reactions >= 0),
      assert(createdAt.isUtc);

  /// Date of this snapshot.
  final DateTime date;

  /// Full repository name in `organization/name` format.
  final String repository;

  /// GitHub issue number.
  final int id;

  /// GitHub issue title.
  final String title;

  /// GitHub issue state (`OPEN` or `CLOSED`)
  final String state;

  /// Number of GitHub comments on the issue at this date.
  final int comments;

  /// Number of GitHub users participating in the issue conversation at this date.
  final int participants;

  /// Number of GitHub reactions on the issue at this date.
  final int reactions;

  /// When the GitHub issue was created.
  final DateTime createdAt;

  /// The GitHub issue's labels at this date, lowercased.
  ///
  /// Null if this snapshot was captured before labels were supported.
  final List<String>? labels;

  factory IssueSnapshot.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    final labelsJson = json['labels'] as List<dynamic>? ?? const <dynamic>[];

    return IssueSnapshot(
      date: DateTime.utc(date.year, date.month, date.day),
      repository: json['repository'] as String,
      id: json['id'] as int,
      title: json['title'] as String,
      state: json['state'] as String,
      comments: json['comments'] as int,
      participants: json['participants'] as int,
      reactions: json['reactions'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      labels: labelsJson.map((label) => label as String).toList(),
    );
  }

  String toJson() {
    return json.encode({
      'date': dayFormat.format(date),
      'repository': repository,
      'id': id,
      'title': title,
      'state': state,
      'comments': comments,
      'participants': participants,
      'reactions': reactions,
      'createdAt': createdAt.toIso8601String(),
      if (labels != null)
        'labels': labels?.map((l) => l.toLowerCase()).toList(),
    });
  }
}

Future<File> createOutputFile(String outputPath, String name) async {
  final outputDir = Directory(outputPath);
  await outputDir.create(recursive: true);

  final filePath = path.join(outputPath, name);

  return File(filePath);
}

Future<List<IssueSnapshot>> readSnapshotsDirectory(Directory directory) async {
  final result = <IssueSnapshot>[];

  final entities = directory.listSync(recursive: true);
  for (final entity in entities) {
    if (entity is File && entity.path.endsWith('.jsonl')) {
      final snapshots = await readSnapshotsFile(entity);

      result.addAll(snapshots);
    }
  }

  return result;
}

Future<List<IssueSnapshot>> readSnapshotsFile(File file) async {
  final result = <IssueSnapshot>[];

  final lines = await file.readAsLines();
  for (final line in lines) {
    final snapshotJson = json.decode(line) as Map<String, dynamic>;
    final snapshot = IssueSnapshot.fromJson(snapshotJson);

    result.add(snapshot);
  }

  return result;
}

Future<void> writeSnapshots(
  IOSink writer,
  List<IssueSnapshot> snapshots,
) async {
  for (final snapshot in snapshots) {
    final snapshotJson = json.encode({
      'date': dayFormat.format(snapshot.date),
      'repository': snapshot.repository,
      'id': snapshot.id,
      'title': snapshot.title,
      'state': snapshot.state,
      'comments': snapshot.comments,
      'participants': snapshot.participants,
      'reactions': snapshot.reactions,
      'createdAt': snapshot.createdAt.toIso8601String(),
      if (snapshot.labels != null)
        'labels': snapshot.labels?.map((l) => l.toLowerCase()).toList(),
    });

    writer.writeln(snapshotJson);
  }

  await writer.flush();
  await writer.close();
}

class IssueDelta {
  const IssueDelta({
    required this.id,
    required this.repository,
    required this.name,
    required this.url,
    required this.open,
    required this.labels,
    required this.totalReactions,
    required this.recentReactions,
    required this.buckets,
    required this.values,
  }) : assert(buckets.length == values.length);

  final int id;
  final String repository;
  final String name;
  final Uri url;
  final bool open;
  final List<String> labels;

  final int totalReactions;
  final int recentReactions;

  final List<String> buckets;
  final List<int> values;
}

const _minimumRecentReactionsForGraph = 5;

void writeDashboard(
  IOSink writer,
  List<IssueDelta> deltas,
  DateTime start, // inclusive
  DateTime end, // exclusive
) {
  final window =
    'from ${dayFormat.format(start)} '
    'to ${dayFormat.format(end.add(Duration(days: -1)))}';

  bool Function(IssueDelta) hasLabel(String label) =>
    (IssueDelta delta) => delta.labels.any((l) => l == label);

  // Filter out issues that are closed.
  // Sort by recent reactions descending, then by total reactions descending.
  deltas = deltas.where((delta) => delta.open).toList();
  deltas.sort((a, b) {
    final recentComparison = b.recentReactions.compareTo(a.recentReactions);
    if (recentComparison != 0) {
      return recentComparison;
    }

    return b.totalReactions.compareTo(a.totalReactions);
  });

  final mostReactions = deltas.take(15).toList();
  final cupertino = deltas.where(hasLabel('f: cupertino')).take(15).toList();
  final dartSdk = deltas.where((delta) => delta.repository == 'dart-lang/sdk').take(15).toList();
  final dartLanguage = deltas.where((delta) => delta.repository == 'dart-lang/language').take(15).toList();

  final teamAndroid = deltas.where(hasLabel('team-android')).take(15).toList();
  final teamDesign = deltas.where(hasLabel('team-design')).take(15).toList();
  final teamEcosystem = deltas.where(hasLabel('team-web')).take(15).toList();
  final teamEngine = deltas.where(hasLabel('team-engine')).take(15).toList();
  final teamFramework = deltas.where(hasLabel('team-framework')).take(15).toList();
  final teamGoRouter = deltas.where(hasLabel('team-go_router')).take(15).toList();
  final teamiOS = deltas.where(hasLabel('team-ios')).take(15).toList();
  final teamTextInput = deltas.where(hasLabel('team-text-input')).take(15).toList();
  final teamTool = deltas.where(hasLabel('team-tool')).take(15).toList();
  final teamWeb = deltas.where(hasLabel('team-web')).take(15).toList();

  final teamDesktop =
    deltas
      .where((delta) =>
        delta
          .labels
          .any((label) =>
            label == 'team-windows' ||
            label == 'team-macos' ||
            label == 'team-linux'
          )
      )
    .take(15)
    .toList();

  final all = [
    ...mostReactions,
    ...cupertino,
    ...dartSdk,
    ...dartLanguage,
    ...teamAndroid,
    ...teamDesign,
    ...teamEcosystem,
    ...teamEngine,
    ...teamFramework,
    ...teamGoRouter,
    ...teamiOS,
    ...teamTool,
    ...teamTextInput,
    ...teamWeb,
    ...teamDesktop,
  ];

  final allIds = all.map((delta) => '${delta.repository}#${delta.id}').toSet();
  final graphs = deltas
    .where((delta) => delta.recentReactions >= _minimumRecentReactionsForGraph)
    .where((delta) => allIds.contains('${delta.repository}#${delta.id}'))
    .toList();

  writer.writeln('# GitHub Insights');
  writer.writeln();

  writer.writeln('## Trending issues');
  writer.writeln();

  writer.writeln('Issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, mostReactions);

  writer.writeln('## Trending issues by team');
  writer.writeln();

  writer.writeln('### Framework');
  writer.writeln();

  writer.writeln('#### Framework');
  writer.writeln();

  writer.writeln('`team-framework` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamFramework);

  writer.writeln('#### Design');
  writer.writeln();

  writer.writeln('`team-design` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamDesign);

  writer.writeln('#### Cupertino');
  writer.writeln();

  writer.writeln('`f: cupertino` issues that received the most reactions $window.');

  _writeIssueDeltasTable(writer, cupertino);

  writer.writeln('#### Text input');
  writer.writeln();

  writer.writeln('`team-text-input` issues that received the most reactions $window.');

  _writeIssueDeltasTable(writer, teamTextInput);

  writer.writeln('#### go_router');
  writer.writeln();

  writer.writeln('`team-go_router` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamGoRouter);

  writer.writeln('### Tool');
  writer.writeln();

  writer.writeln('`team-tool` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamTool);

  writer.writeln('### Engine');
  writer.writeln();

  writer.writeln('`team-engine` issues that received the most reactions $window.');

  _writeIssueDeltasTable(writer, teamEngine);

  writer.writeln('### Platforms');
  writer.writeln();

  writer.writeln('#### iOS');
  writer.writeln();

  writer.writeln('`team-ios` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamiOS);

  writer.writeln('#### Android');
  writer.writeln();

  writer.writeln('`team-android` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamAndroid);

  writer.writeln('#### Web');
  writer.writeln();

  writer.writeln('`team-web` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamWeb);

  writer.writeln('#### Desktop');
  writer.writeln();

  writer.writeln('`team-desktop` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamDesktop);

  writer.writeln('### Ecosystem');
  writer.writeln();

  writer.writeln('`team-ecosystem` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, teamEcosystem);

  writer.writeln('### Dart SDK');
  writer.writeln();

  writer.writeln('`dart-lang/sdk` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, dartSdk);

  writer.writeln('### Dart language');
  writer.writeln();

  writer.writeln('`dart-lang/language` issues that received the most reactions $window.');
  writer.writeln();

  _writeIssueDeltasTable(writer, dartLanguage);

  writer.writeln('## Graphs');
  writer.writeln();

  _writeIssueDeltasList(writer, graphs);
}

void _writeIssueDeltasTable(
  IOSink writer,
  List<IssueDelta> issues,
) {
  writer.writeln('Issue | Total reactions | Recent reactions');
  writer.writeln('-- | -- | --');

  for (final issue in issues) {
    final repositoryId = issue.repository.replaceFirst('/', '-');

    // Escape the pipe character in the issue name.
    final name = issue.name.replaceAll('|', '\\|');

    writer.write('$name ');
    writer.write('[${issue.repository}#${issue.id}](${issue.url}) ');
    writer.write('| ${issue.totalReactions} | ');
    if (issue.recentReactions >= _minimumRecentReactionsForGraph) {
      writer.write('[${issue.recentReactions}](#$repositoryId-${issue.id}-graph)');
    } else {
      writer.write(issue.recentReactions);
    }
    writer.writeln();
  }

  writer.writeln();
}

void _writeIssueDeltasList(
  IOSink writer,
  List<IssueDelta> issues,
) {
  for (final issue in issues) {
    final repositoryId = issue.repository.replaceFirst('/', '-');

    writer.writeln('<a name="$repositoryId-${issue.id}-graph"></a>');
    writer.write('### ${issue.name}');
    writer.writeln();

    writer.write('  ');
    writer.write('<sub>');
    writer.write('[${issue.repository}#${issue.id}](${issue.url}) ');
    writer.write('&mdash; ');
    writer.write('${issue.totalReactions} total reactions, ');
    writer.write('${issue.recentReactions} recent reactions');
    writer.write('</sub>');
    writer.write('<br />');
    writer.writeln();

    writer.writeln('  <sub>');
    writer.writeln('  <details>');
    writer.writeln('  <summary>Graph...</summary>');
    writer.writeln();

    writer.writeln('  ```mermaid');
    writer.writeln('  xychart-beta');
    writer.writeln('    x-axis "Week" [${issue.buckets.join(', ')}]');
    if (issue.values.any((v) => v > 20)) {
      writer.writeln('    y-axis "Reactions"');
    } else {
      writer.writeln('    y-axis "Reactions" 0 --> 20');
    }
    writer.writeln('    line [${issue.values.join(', ')}]');
    writer.writeln('  ```');
    writer.writeln();

    writer.writeln('  </details>');
    writer.writeln('  </sub>');
    writer.writeln();
  }
}

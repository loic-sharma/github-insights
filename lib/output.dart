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
  final List<String> labels;

  final int totalReactions;
  final int recentReactions;

  final List<String> buckets;
  final List<int> values;
}

void writeIssueDeltas(
  IOSink writer,
  List<IssueDelta> issues,
) {
  for (final issue in issues) {
    writer.write('* ${issue.name}<br />');
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
    writer.writeln('    bar [${issue.values.join(', ')}]');
    writer.writeln('  ```');
    writer.writeln();

    writer.writeln('  </details>');
    writer.writeln('  </sub>');
    writer.writeln();
  }
}

void writeIssueDeltaGraphs(
  IOSink writer,
  List<IssueDelta> issues,
) {
  for (final issue in issues) {
    final repositoryId = issue.repository.replaceFirst('/', '-');

    writer.writeln('<a name="$repositoryId-${issue.id}-graph"></a>');
    writer.writeln('### ${issue.name}');
    writer.writeln();

    writer.writeln('[${issue.repository}#${issue.id}](${issue.url})');
    writer.writeln();

    writer.writeln('```mermaid');
    writer.writeln('xychart-beta');
    writer.writeln('  x-axis "Week" [${issue.buckets.join(', ')}]');
    if (issue.values.any((v) => v > 20)) {
      writer.writeln('  y-axis "Reactions"');
    } else {
      writer.writeln('  y-axis "Reactions" 0 --> 20');
    }
    writer.writeln('  bar [${issue.values.join(', ')}]');
    writer.writeln('```');
    writer.writeln();

    writer.writeln('</details>');
    writer.writeln('</a>');
    writer.writeln();
  }
}

void writeIssueDeltasTable(
  IOSink writer,
  List<IssueDelta> issues,
) {
  writer.writeln('Issue | Total reactions | Recent reactions');
  writer.writeln('-- | -- | --');

  for (final issue in issues) {
    final repositoryId = issue.repository.replaceFirst('/', '-');
  
    writer.write('${issue.name} ');
    writer.write('[${issue.repository}#${issue.id}](${issue.url}) ');
    writer.write('| ${issue.totalReactions} | ');
    if (issue.recentReactions >= 5) {
      writer.write('[${issue.recentReactions}](#$repositoryId-${issue.id}-graph)');
    } else {
      writer.write(issue.recentReactions);
    }
    writer.writeln();
  }

  writer.writeln();
}

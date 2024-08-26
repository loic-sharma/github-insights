import 'dart:io';
import 'dart:convert';

import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as path;

import 'package:github_insights/logic.dart';

class IssueSnapshot {
  IssueSnapshot(
    this.date,
    this.repository,
    this.id,
    this.title,
    this.state,
    this.comments,
    this.participants,
    this.reactions,
    this.createdAt,
    this.labels,
  ) : assert(date.isUtc),
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
}

Future<File> createOutputFile(String outputPath, String name) async {
  final outputDir = Directory(outputPath);
  await outputDir.create(recursive: true);

  final filePath = path.join(outputPath, name);

  return File(filePath);
}

Future<void> writeSnapshots(
  IOSink writer,
  List<IssueSnapshot> snapshots,
) async {
  final dayFormat = intl.DateFormat('yyyy-MM-dd');
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

class TrendingIssue {
  const TrendingIssue({
    required this.id,
    required this.name,
    required this.url,
    required this.totalReactions,
    required this.recentReactions,
    required this.buckets,
    required this.values,
  });

  final int id;
  final String name;
  final Uri url;
  final int totalReactions;
  final int recentReactions;

  final List<String> buckets;
  final List<int> values;
}

void writeTrendingIssues(
  IOSink writer,
  String owner,
  String repository,
  List<TrendingIssue> issues,
) {
  for (final issue in issues) {
    writer.write('* ${issue.name}<br />');
    writer.writeln();

    writer.write('  ');
    writer.write('<sub>');
    writer.write('[$owner/$repository#${issue.id}](${issue.url}) ');
    writer.write('&mdash; ');
    writer.write('${issue.totalReactions} total reactions, ${issue.recentReactions} recent reactions');
    writer.write('</sub>');
    writer.write('<br />');
    writer.writeln();

    writer.writeln('  <sub>');
    writer.writeln('  <details>');
    writer.writeln('  <summary>Graph...</summary>');
    writer.writeln();

    writer.writeln('  ```mermaid');
    writer.writeln('  xychart-beta');
    writer.writeln('    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]');
    writer.writeln('    y-axis "Reactions"');
    writer.writeln('    bar [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]');
    writer.writeln('  ```');
    writer.writeln();

    writer.writeln('  </details>');
    writer.writeln('  </sub>');
    writer.writeln();
  }
}

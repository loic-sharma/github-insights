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
    });

    writer.writeln(snapshotJson);
  }

  await writer.flush();
  await writer.close();
}

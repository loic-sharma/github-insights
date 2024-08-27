import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:github_insights/logic.dart';
import 'package:github_insights/github.dart' as github;
import 'package:github_insights/output.dart' as output;
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as path;

final String? token = Platform.environment['GITHUB_TOKEN'];

void main(List<String> arguments) async {
  final description = '''
Collect GitHub data.

Common commands:

  github_insights top_issues --repository flutter/flutter --top 1000
    Collect the top 1000 issues from the flutter/flutter repository.

  github_insights reactions --repository flutter/flutter --issue 123
    Collect the reactions for issue flutter/flutter#123.
''';
  final runner = CommandRunner('github_insights', description);

  runner.addCommand(TopIssuesCommand());
  runner.addCommand(BackfillCommand());
  runner.addCommand(DashboardCommand());

  await runner.run(arguments);
}

class TopIssuesCommand extends Command {
  @override
  final String name = 'top_issues';

  @override
  final String description = 'Collect the top issues from a repository.';

  TopIssuesCommand() {
    argParser.addOption(
      'repository',
      help: 'The repository whose top issues should be loaded.',
      defaultsTo: 'flutter/flutter',
    );
    argParser.addOption(
      'top',
      help: 'The count of top issues to load.',
      defaultsTo: '1000',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'The output directory to write the data to.',
      defaultsTo: 'data/flutter/flutter',
    );
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final repository = args['repository'] as String;
    final limit = int.parse(args['top'] as String);
    final outputPath = path.canonicalize(args['output'] as String);

    validateRepository(repository);

    final stopwatch = Stopwatch()..start();

    print('Loading top issues...');
    final issues = await loadTopIssues(token, repository, limit);
    print('Loaded ${issues.length} issues');
    print('');

    final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.timestamp());
    final outputFile =
        await output.createOutputFile(outputPath, '$today.jsonl');

    await output.writeSnapshots(outputFile.openWrite(), issues);
    print('Wrote ${outputFile.path} in ${stopwatch.elapsedMilliseconds}ms');
  }
}

class BackfillCommand extends Command {
  @override
  final String name = 'backfill';

  @override
  final String description = "Collect an issue's historical data.";

  BackfillCommand() {
    argParser.addOption(
      'repository',
      help: 'The repository name. Example: flutter/flutter',
      mandatory: true,
    );
    argParser.addOption(
      'issue',
      help: 'The issue number.',
      mandatory: true,
    );
    argParser.addOption(
      'until',
      help: 'The UTC end date for the backfill, exclusive. YYYY-MM-DD format.',
      defaultsTo: '3000-01-01',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'The output file to write the data to.',
      defaultsTo: path.join('data', 'flutter', 'flutter', 'backfill'),
    );
  }

  @override
  Future<void> run() async {
    DateTime parseUtc(String date) {
      final parsed = DateTime.parse(date);
      return DateTime.utc(parsed.year, parsed.month, parsed.day);
    }

    final args = argResults!;
    final repositoryAndOwner = args['repository'] as String;
    final issueId = int.parse(args['issue'] as String);
    final cutoff = parseUtc(args['until'] as String);
    final outputPath = path.canonicalize(args['output'] as String);

    validateRepository(repositoryAndOwner);
    final parts = repositoryAndOwner.split('/');
    final owner = parts[1];
    final repository = parts[0];

    final stopwatch = Stopwatch()..start();

    print('Loading issue...');
    final issueResult =
        await github.loadIssue(token, owner, repository, issueId);
    final issue = issueResult.issue;
    print('');

    print('Loading timeline...');
    final timeline = await loadTimeline(token, owner, repository, issueId);
    print('Loaded ${timeline.length} timeline events');
    print('');

    print('Loading reactions...');
    final reactions = await loadReactions(token, owner, repository, issueId);
    print('Loaded ${reactions.length} reactions');
    print('');

    print('Creating snapshots...');
    final snapshots = createSnapshots(
      repositoryAndOwner,
      issue,
      timeline,
      reactions,
      cutoff,
    );
    print('Created ${snapshots.length} snapshots');
    print('');

    final outputDir = path.dirname(outputPath);
    final outputName = path.basename(outputPath);
    final outputFile = await output.createOutputFile(outputDir, outputName);

    await output.writeSnapshots(outputFile.openWrite(), snapshots);

    print('Wrote ${outputFile.path} in ${stopwatch.elapsedMilliseconds}ms');
  }
}

class DashboardCommand extends Command {
  @override
  final String name = 'dashboard';

  @override
  final String description = "Create a dashboard from issue data.";

  DashboardCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'The output file to write the data to.',
      defaultsTo: path.join('dashboard.md'),
    );
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final dataPath = 'top_issues'; // TODO
    final outputPath = path.canonicalize(args['output'] as String);

    final stopwatch = Stopwatch()..start();

    print('Reading issue snapshots...');
    final snapshots = await output.readSnapshotsDirectory(Directory(dataPath));
    print('Read ${snapshots.length} snapshots');

    final endDate = DateTime.timestamp().add(Duration(days: 1));
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final start = startOfWeekUtc(end.add(Duration(days: -90)));

    final deltas = calculateIssueDeltas(snapshots, start, end);

    // Sort by recent reactions descending.
    deltas.sort((a, b) => b.recentReactions.compareTo(a.recentReactions));

    print('Writing dashboard file...');
    final outputDir = path.dirname(outputPath);
    final outputName = path.basename(outputPath);
    final outputFile = await output.createOutputFile(outputDir, outputName);

    final writer = outputFile.openWrite();

    writer.writeln('# GitHub Insights');
    writer.writeln();

    writer.writeln('## Trending issues');
    writer.writeln();

    output.writeIssueDeltas(
      writer,
      deltas.take(15).toList(),
    );

    writer.writeln('## Trending issues by team');
    writer.writeln();

    writer.writeln('### Framework');
    writer.writeln();

    writer.writeln('#### Framework');
    writer.writeln();

    writer.writeln('team-framework issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-framework')).take(15).toList(),
    );

    writer.writeln('#### Design');
    writer.writeln();

    writer.writeln('team-design issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-design')).take(15).toList(),
    );

    writer.writeln('#### Cupertino');
    writer.writeln();

    writer.writeln('f: cupertino issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('f: cupertino')).take(15).toList(),
    );

    writer.writeln('#### go_router');
    writer.writeln();

    writer.writeln('team-go_router issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-go_router')).take(15).toList(),
    );

    writer.writeln('### Tool');
    writer.writeln();

    writer.writeln('team-tool issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-tool')).take(15).toList(),
    );

    writer.writeln('### Engine');
    writer.writeln();

    writer.writeln('team-engine issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-engine')).take(15).toList(),
    );

    writer.writeln('### Platforms');
    writer.writeln();

    writer.writeln('#### iOS');
    writer.writeln();

    writer.writeln('team-ios issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-ios')).take(15).toList(),
    );

    writer.writeln('#### Android');
    writer.writeln();

    writer.writeln('team-android issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-android')).take(15).toList(),
    );

    writer.writeln('#### Web');
    writer.writeln();

    writer.writeln('team-web issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-web')).take(15).toList(),
    );

    writer.writeln('#### Desktop');
    writer.writeln();

    writer.writeln('team-desktop issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-desktop')).take(15).toList(),
    );

    writer.writeln('### Ecosystem');
    writer.writeln();

    writer.writeln('team-ecosystem issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where(hasLabel('team-ecosystem')).take(15).toList(),
    );

    writer.writeln('### Dart SDK');
    writer.writeln();

    writer.writeln('dart-lang/sdk issues that received the most reactions from TODO to TODO');

    output.writeIssueDeltas(
      writer,
      deltas.where((delta) => delta.repository == 'dart-lang/sdk').take(15).toList(),
    );

    await writer.flush();
    await writer.close();

    print('Wrote ${outputFile.path} in ${stopwatch.elapsedMilliseconds}ms');
  }
}

bool Function(output.IssueDelta) hasLabel(String label)
  => (output.IssueDelta delta ) => delta.labels.any((l) => l == label);
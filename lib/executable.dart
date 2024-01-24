import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart' as args;
import 'package:intl/intl.dart' as intl;
import 'package:github_insights/github.dart' as github;
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  String? token = Platform.environment['GITHUB_TOKEN'];

  var parser = args.ArgParser();

  parser.addOption(
    'repository',
    help: 'The repository whose top issues should be loaded..',
    defaultsTo: 'flutter/flutter',
  );
  parser.addOption(
    'top',
    help: 'The count of top issues to load.',
    defaultsTo: '1000',
  );
  parser.addOption(
    'output',
    abbr: 'o',
    help: 'The output directory to write the data to.',
    defaultsTo: 'data/flutter/flutter',
  );

  final results = parser.parse(arguments);
  final repository = results['repository'];
  final limit = int.parse(results['top']);
  final outputPath = path.canonicalize(results['output']);

  validateRepository(repository);

  final stopwatch = Stopwatch()..start();

  print('Loading top issues...');
  final issues = await loadTopIssues(token, repository, limit);
  print('Loaded ${issues.length} issues');
  print('');

  final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.timestamp());
  final outputFile = await createOutputFile(outputPath, today);

  await writeIssues(outputFile.openWrite(), today, repository, issues);
  print('Wrote ${outputFile.path} in ${stopwatch.elapsedMilliseconds}ms');
}

void validateRepository(String repository) {
  final regex = RegExp(r'^[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+$');
  if (!regex.hasMatch(repository)) {
    throw 'Invalid repository $repository. Expected format is owner/repo.';
  }
}

Future<List<github.Issue>> loadTopIssues(
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
  issues.sort((a, b) => compareIssues(b, a));

  return issues.take(limit).toList();
}

Future<File> createOutputFile(String outputPath, String date) async {
  final outputDir = Directory(outputPath);
  await outputDir.create(recursive: true);

  final filePath = path.join(outputPath, '$date.jsonl');

  return File(filePath);
}

Future<void> writeIssues(
  IOSink writer,
  String date,
  String repository,
  List<github.Issue> issues,
) async {
  for (final issue in issues) {
    final issueJson = json.encode({
      'date': date,
      'repository': repository,
      'id': issue.number,
      'title': issue.title,
      'state': issue.state,
      'comments': issue.comments,
      'participants': issue.participants,
      'reactions': issue.reactions,
      'createdAt': issue.createdAt.toIso8601String(),
    });

    writer.writeln(issueJson);
  }

  await writer.flush();
  await writer.close();
}

int compareIssues(github.Issue a, github.Issue b) {
  final reactionsComparison = a.reactions.compareTo(b.reactions);
  if (reactionsComparison != 0) {
    return reactionsComparison;
  }

  return a.number.compareTo(b.number);
}

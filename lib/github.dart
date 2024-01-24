import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<TopIssuesResult> loadTopIssues(
  String? token,
  String repository,
  String? after,
) async {
  return await _runQuery(
    token: token,
    body: json.encode({
      'query': _topIssuesQuery(repository),
      'variables': {
        'after': after,
      },
    }),
    resultCallback: TopIssuesResult.fromJson,
  );
}

Future<T> _runQuery<T>({
  String? token,
  String? body,
  required T Function(Map<String, dynamic>) resultCallback,
}) async {
  final uri = Uri.parse('https://api.github.com/graphql');
  final headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    'X-Request-Type': 'GraphQL',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  for (var attempt = 0; attempt < 3; attempt++) {
    stdout.write('POST $uri...');
    await stdout.flush();

    final timer = Stopwatch()..start();
    final response = await http.post(uri, body: body, headers: headers);

    stdout.writeln(' HTTP ${response.statusCode} (${timer.elapsed.inMilliseconds}ms)');

    if (response.statusCode != 200) {
      print('Attempt ${attempt + 1}/3...');
      await Future.delayed(Duration(seconds: 3));
      continue;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return resultCallback(json);
  }

  throw 'Failed to run query in 3 attempts.';
}

String _topIssuesQuery(String repository) =>
'''
query (\$after: String) {
  search(
    query: "repo:$repository is:open sort:reactions-+1-desc"
    type: ISSUE
    first: 100
    after: \$after
  ) {
    pageInfo {
      endCursor
      hasNextPage
    }
    edges {
      node {
        ... on Issue {
          comments {
            totalCount
          }
          createdAt
          number
          participants {
            totalCount
          }
          publishedAt
          reactions {
            totalCount
          }
          state
          title
        }
      }
    }
  }
}
''';

class TopIssuesResult {
  TopIssuesResult({
    required this.endCursor,
    required this.hasNextPage,
    required this.issues,
  });

  final String? endCursor;
  final bool hasNextPage;
  final List<Issue> issues;

  factory TopIssuesResult.fromJson(Map<String, dynamic> json) {
    final endCursor = json['data']['search']['pageInfo']['endCursor'] as String?;
    final hasNextPage = json['data']['search']['pageInfo']['hasNextPage'] as bool;
    final edges = json['data']['search']['edges'] as List<dynamic>;

    final issues = <Issue>[];
    for (final edge in edges) {
      _tryParseJson(
        'issue',
        edge,
        () => issues.add(Issue.fromJson(edge['node'] as Map<String, dynamic>)),
      );
    }

    return TopIssuesResult(
      endCursor: endCursor,
      hasNextPage: hasNextPage,
      issues: issues,
    );
  }
}

class Issue {
  Issue({
    required this.comments,
    required this.createdAt,
    required this.number,
    required this.participants,
    required this.publishedAt,
    required this.reactions,
    required this.state,
    required this.title,
  });

  final int comments;
  final DateTime createdAt;
  final int number;
  final int participants;
  final DateTime publishedAt;
  final int reactions;
  final String state;
  final String title;

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      comments: json['comments']?['totalCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      number: json['number'] as int,
      participants: json['participants']?['totalCount'] as int? ?? 0,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      reactions: json['reactions']?['totalCount'] as int? ?? 0,
      state: json['state'] as String,
      title: json['title'] as String,
    );
  }
}

void _tryParseJson<T>(String type, T json, void Function() parse) {
  try {
    parse();
  } catch (e, s) {
    print('Ignoring error parsing $type JSON: "$e"');
    print('');
    print('JSON:');
    print(json);
    print('');
    print(s);
  }
}

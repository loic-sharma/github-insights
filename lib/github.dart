import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<TopIssuesResult> loadTopIssues(
  String? token,
  String repository,
  String? after,
) async {
  return await _graphqlApi(
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

Future<IssueResult> loadIssue(
  String? token,
  String owner,
  String repository,
  int issue,
) async {
  return await _graphqlApi(
    token: token,
    body: json.encode({
      'query': _issueQuery(owner, repository, issue),
    }),
    resultCallback: IssueResult.fromJson,
  );
}

Future<ReactionsResult> loadReactions(
  String? token,
  String owner,
  String repository,
  int issue, {
  int perPage = 100,
  int page = 1,
}) async {
  final uri = Uri.parse(
    'https://api.github.com/repos/$owner/$repository/issues/$issue/reactions'
    '?per_page=$perPage&page=$page'
  );

  return await _restApi(
    token: token,
    uri: uri,
    resultCallback: ReactionsResult.fromResponse,
  );
}

Future<TimelineResult> loadTimeline(
  String? token,
  String owner,
  String repository,
  int issue, {
  int perPage = 100,
  int page = 1,
}) async {
  final uri = Uri.parse(
    'https://api.github.com/repos/$owner/$repository/issues/$issue/timeline'
    '?per_page=$perPage&page=$page'
  );

  return await _restApi(
    token: token,
    uri: uri,
    resultCallback: TimelineResult.fromResponse,
  );
}

Future<T> _graphqlApi<T>({
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
      print('Reason: ${response.reasonPhrase}');
      print('Attempt ${attempt + 1}/3...');
      await Future.delayed(Duration(seconds: 3));
      continue;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return resultCallback(json);
  }

  throw 'Failed to run query in 3 attempts.';
}

Future<T> _restApi<T>({
  String? token,
  required Uri uri,
  required T Function(http.Response) resultCallback,
}) async {
  final headers = <String, String>{
    'Accept': 'application/vnd.github+json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  for (var attempt = 0; attempt < 3; attempt++) {
    stdout.write('GET $uri...');
    await stdout.flush();

    final timer = Stopwatch()..start();
    final response = await http.get(uri, headers: headers);

    stdout.writeln(' HTTP ${response.statusCode} (${timer.elapsed.inMilliseconds}ms)');

    if (response.statusCode != 200) {
      print('Reason: ${response.reasonPhrase}');
      print('Attempt ${attempt + 1}/3...');
      await Future.delayed(Duration(seconds: 3));
      continue;
    }

    return resultCallback(response);
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
          labels(first: 20) {
            edges {
              node {
                name
              }
            }
          }
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
    required this.labels,
    required this.number,
    required this.participants,
    required this.publishedAt,
    required this.reactions,
    required this.state,
    required this.title,
  });

  final int comments;
  final DateTime createdAt;
  final List<String> labels;
  final int number;
  final int participants;
  final DateTime publishedAt;
  final int reactions;
  final String state;
  final String title;

  factory Issue.fromJson(Map<String, dynamic> json) {
    final labels = <String>[];
    final labelsJson = json['labels']?['edges'] as List<dynamic>? ?? const <dynamic>[];
    for (final labelJson in labelsJson) {
      labels.add(labelJson['node']['name']);
    }

    return Issue(
      comments: json['comments']?['totalCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      labels: labels,
      number: json['number'] as int,
      participants: json['participants']?['totalCount'] as int? ?? 0,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      reactions: json['reactions']?['totalCount'] as int? ?? 0,
      state: json['state'] as String,
      title: json['title'] as String,
    );
  }
}

String _issueQuery(String owner, String repository, int issue) =>
'''
query {
  repository(owner: "$owner", name: "$repository") {
    issue(number: $issue) {
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
''';

class IssueResult {
  IssueResult(this.issue);

  final Issue issue;

  factory IssueResult.fromJson(Map<String, dynamic> json) {
    final issueJson = json['data']['repository']['issue'] as Map<String, dynamic>;
    return IssueResult(Issue.fromJson(issueJson));
  }
}

class ReactionsResult {
  ReactionsResult(this.events, this.links);

  final List<ReactionEvent> events;

  final PaginationLinks links;

  factory ReactionsResult.fromResponse(http.Response response) {
    final json = jsonDecode(response.body) as List<dynamic>;

    final events = <ReactionEvent>[];
    for (final reactionJson in json) {
      events.add(ReactionEvent.fromJson(reactionJson as Map<String, dynamic>));
    }

    final links = PaginationLinks.fromResponse(response);
    return ReactionsResult(events, links);
  }
}

class ReactionEvent {
  ReactionEvent(this.content, this.createdAt, this.userLogin, this.userType);

  // +1, -1, laugh, confused, heart, hooray, rocket, eyes
  final String content;

  final DateTime createdAt;

  final String userLogin;
  final String userType;

  factory ReactionEvent.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    final createdAt = DateTime.parse(json['created_at'] as String);
    final userJson = json['user'] as Map<String, dynamic>;
    final userLogin = userJson['login'] as String;
    final userType = userJson['type'] as String;

    return ReactionEvent(content, createdAt, userLogin, userType);
  }
}

class TimelineResult {
  TimelineResult(this.events, this.links);

  final List<TimelineEvent> events;

  final PaginationLinks links;

  factory TimelineResult.fromResponse(http.Response response) {
    final json = jsonDecode(response.body) as List<dynamic>;

    final events = <TimelineEvent>[];
    for (final reactionJson in json) {
      events.add(TimelineEvent.fromJson(reactionJson as Map<String, dynamic>));
    }

    final links = PaginationLinks.fromResponse(response);
    return TimelineResult(events, links);
  }
}

class TimelineEvent {
  TimelineEvent({
    required this.event,
    required this.actorLogin,
    required this.actorType,
    required this.createdAt,
  });

  final String event;
  final String actorLogin;
  final String actorType;
  final DateTime? createdAt;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDate(String? date)
      => date == null ? null : DateTime.parse(date);

    final event = json['event'];
    final createdAt = parseNullableDate(json['created_at'] as String?);
    final actorJson = json['actor'] as Map<String, dynamic>?;
    final actorLogin = actorJson?['login'] as String? ?? 'null';
    final actorType = actorJson?['type'] as String? ?? 'null';

    return TimelineEvent(
      event: event,
      actorLogin: actorLogin,
      actorType: actorType,
      createdAt: createdAt!,
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

class PaginationLinks {
  PaginationLinks._([this.previous, this.next, this.first, this.last]);

  final Uri? previous;
  final Uri? next;
  final Uri? first;
  final Uri? last;

  factory PaginationLinks.fromResponse(http.Response response) {
    final header = response.headers['link'];
    if (header == null) {
      return PaginationLinks._();
    }

    Uri? previous;
    Uri? next;
    Uri? first;
    Uri? last;

    final regex = RegExp(r'<(.*?)>; rel="(.*?)"');
    final matches = regex.allMatches(header);

    for (final match in matches) {
      final url = Uri.parse(match.group(1)!);
      final name = match.group(2)!;

      switch (name) {
        case 'prev': previous = url; break;
        case 'next': next = url; break;
        case 'first': first = url; break;
        case 'last': last = url; break;
        default: throw 'Unknown pagination link name $name';
      }
    }

    return PaginationLinks._(previous, next, first, last);
  }
}

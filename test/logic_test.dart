import 'package:github_insights/logic.dart';
import 'package:github_insights/output.dart';
import 'package:test/test.dart';

void main() {
  group('Issue deltas', () {
    test('existing issue', () {
      final deltas = calculateIssueDeltas(
        [
          IssueSnapshot(
            date: DateTime.utc(2024, 1, 1),
            repository: 'flutter/flutter',
            id: 1,
            title: 'Hello world',
            state: 'OPEN',
            comments: 0,
            participants: 0,
            reactions: 2,
            createdAt: DateTime.utc(2000, 1, 1),
            labels: [],
          ),
          IssueSnapshot(
            date: DateTime.utc(2024, 1, 6),
            repository: 'flutter/flutter',
            id: 1,
            title: 'Hello world',
            state: 'OPEN',
            comments: 0,
            participants: 0,
            reactions: 5,
            createdAt: DateTime.utc(2000, 1, 1),
            labels: [],
          ),
        ],
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 1, 7),
      );

      expect(deltas.length, equals(1));
      expect(
        deltas[0].buckets,
        equals(['Jan 1']),
      );
      expect(deltas[0].values, equals([3]));
    });

    test('new issue', () {
      final deltas = calculateIssueDeltas(
        [
          IssueSnapshot(
            date: DateTime.utc(2024, 1, 2),
            repository: 'flutter/flutter',
            id: 1,
            title: 'Hello world',
            state: 'OPEN',
            comments: 0,
            participants: 0,
            reactions: 5,
            createdAt: DateTime.utc(2024, 1, 2),
            labels: [],
          ),
          IssueSnapshot(
            date: DateTime.utc(2024, 1, 3),
            repository: 'flutter/flutter',
            id: 1,
            title: 'Hello world',
            state: 'OPEN',
            comments: 0,
            participants: 0,
            reactions: 10,
            createdAt: DateTime.utc(2024, 1, 2),
            labels: [],
          ),
        ],
        DateTime.utc(2024, 1, 1),
        DateTime.utc(2024, 1, 4),
      );

      expect(deltas.length, equals(1));
      expect(
        deltas[0].buckets,
        equals(['Jan 1']),
      );
      expect(deltas[0].values, equals([10]));
    });
  });
}

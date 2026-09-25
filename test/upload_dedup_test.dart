import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/services/analysis_service.dart';

void main() {
  group('UploadResult duplicate semantics', () {
    test('a reused upload reuses the existing task instead of a new one', () {
      final result = UploadResult.fromJson({
        'success': true,
        'task_id': 'task-existing',
        'status': 'success',
        'md5': 'd41d8cd98f00b204e9800998ecf8427e',
        'sha256':
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'filename': 'demo.apk',
        'deduplicated': true,
        'queue_state': 'reused',
      });

      expect(result.isDuplicate, isTrue);
      expect(result.isReused, isTrue);
      expect(result.isCompletedReuse, isTrue);
      expect(result.taskId, 'task-existing');
    });

    test('an in-flight reuse is a duplicate but not yet a finished report', () {
      final result = UploadResult.fromJson({
        'success': true,
        'task_id': 'task-running',
        'status': 'processing',
        'deduplicated': true,
        'queue_state': 'reused',
      });

      expect(result.isDuplicate, isTrue);
      expect(result.isCompletedReuse, isFalse);
    });

    test('a fresh upload is not a duplicate', () {
      final result = UploadResult.fromJson({
        'success': true,
        'task_id': 'task-new',
        'status': 'queued',
        'deduplicated': false,
        'queue_state': 'dispatched',
      });

      expect(result.isDuplicate, isFalse);
      expect(result.isGapFilled, isFalse);
    });

    test('a gap fill re-runs missing tools so it is not a duplicate', () {
      final result = UploadResult.fromJson({
        'success': true,
        'task_id': 'task-gap',
        'status': 'queued',
        'deduplicated': false,
        'queue_state': 'gap_filled',
      });

      expect(result.isGapFilled, isTrue);
      expect(result.isDuplicate, isFalse);
    });

    test('a check-hash hit maps onto the same duplicate contract', () {
      final result = UploadResult.fromJson({
        'success': true,
        'found': true,
        'task_id': 'task-cached',
        'status': 'success',
        'filename': 'demo.apk',
        'report': {'score': 12},
      });

      expect(result.isDuplicate, isTrue);
      expect(result.isReused, isTrue);
      expect(result.isCompletedReuse, isTrue);
    });

    test('a check-hash miss leaves the upload to run normally', () {
      final result = UploadResult.fromJson({'success': true, 'found': false});

      expect(result.isDuplicate, isFalse);
      expect(result.taskId, isNull);
    });

    test('a check-hash gap fill re-runs the missing tools', () {
      final result = UploadResult.fromJson({
        'success': true,
        'found': true,
        'gap_filled': true,
        'task_id': 'task-refilled',
        'status': 'queued',
      });

      expect(result.isGapFilled, isTrue);
      expect(result.isDuplicate, isFalse);
    });
  });

  group('AnalysisService.computeFileSha256', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rampart-dedup-test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('matches the known digest of an empty file', () async {
      final file = File('${dir.path}/empty.bin');
      await file.writeAsBytes(const []);

      expect(
        await AnalysisService.computeFileSha256(file),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('matches the known digest of "rampart"', () async {
      final file = File('${dir.path}/rampart.txt');
      await file.writeAsString('rampart');

      expect(
        await AnalysisService.computeFileSha256(file),
        'f93f6d73fc1db319ca350eabc6be9df503ae8a2acdda20392b6e60d4bc04c9de',
      );
    });
  });
}

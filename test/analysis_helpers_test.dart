import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/widgets/analysis_components.dart';

void main() {
  group('AnalysisScoreTier', () {
    test('uses the same score boundaries as the web report', () {
      expect(AnalysisScoreTier.fromScore(0).label, 'ปลอดภัย');
      expect(AnalysisScoreTier.fromScore(29.9).label, 'ปลอดภัย');
      expect(AnalysisScoreTier.fromScore(30).label, 'ความเสี่ยงปานกลาง');
      expect(AnalysisScoreTier.fromScore(59.9).label, 'ความเสี่ยงปานกลาง');
      expect(AnalysisScoreTier.fromScore(60).label, 'อันตราย');
      expect(AnalysisScoreTier.fromScore(79.9).label, 'อันตราย');
      expect(AnalysisScoreTier.fromScore(80).label, 'อันตรายร้ายแรง');
      expect(AnalysisScoreTier.fromScore(null).label, 'ปลอดภัย');
    });

    test('maps backend risk levels to the same tiers', () {
      expect(AnalysisScoreTier.fromRisk('Low').label, 'ปลอดภัย');
      expect(AnalysisScoreTier.fromRisk('Caution').label, 'ความเสี่ยงปานกลาง');
      expect(AnalysisScoreTier.fromRisk('High').label, 'อันตราย');
      expect(AnalysisScoreTier.fromRisk('Critical').label, 'อันตรายร้ายแรง');
    });
  });

  group('ToolRunStatus', () {
    test('normalizes the mixed status values from the backend', () {
      expect(ToolRunStatus.fromRaw(null), ToolRunStatus.waiting);
      expect(ToolRunStatus.fromRaw(true), ToolRunStatus.completed);
      expect(ToolRunStatus.fromRaw('success'), ToolRunStatus.completed);
      expect(ToolRunStatus.fromRaw('completed'), ToolRunStatus.completed);
      expect(ToolRunStatus.fromRaw(1), ToolRunStatus.completed);
      expect(ToolRunStatus.fromRaw(false), ToolRunStatus.failed);
      expect(ToolRunStatus.fromRaw('skipped'), ToolRunStatus.skipped);
      expect(ToolRunStatus.fromRaw('processing'), ToolRunStatus.running);
      expect(ToolRunStatus.fromRaw('queued'), ToolRunStatus.running);
    });

    test('derives a stage status from the tools in that stage', () {
      expect(
        deriveAnalysisStageStatus(const [ToolRunStatus.waiting]),
        ToolRunStatus.waiting,
      );
      expect(
        deriveAnalysisStageStatus(const [
          ToolRunStatus.completed,
          ToolRunStatus.running,
        ]),
        ToolRunStatus.running,
      );
      expect(
        deriveAnalysisStageStatus(const [
          ToolRunStatus.completed,
          ToolRunStatus.failed,
        ]),
        ToolRunStatus.completed,
      );
      expect(
        deriveAnalysisStageStatus(const [
          ToolRunStatus.failed,
          ToolRunStatus.skipped,
        ]),
        ToolRunStatus.failed,
      );
      expect(deriveAnalysisStageStatus(const []), ToolRunStatus.waiting);
    });
  });

  group('analysis response models', () {
    test('parses a report tool CSV and maps the report_target key', () {
      final report = AnalysisReport.fromJson({
        'task_id': 'task-1',
        'uid': 'user-1',
        'tools': 'virustotal,mobsf, cape ,rampart_ai,gemini',
        'score': '72.5',
        'risk_level': 'High',
        'risk_indicators': ['Suspicious permission', 'Network access'],
        'tool_notes': '{"mobsf":"apk-only"}',
      });

      expect(report.taskId, 'task-1');
      expect(report.score, 72.5);
      expect(report.toolList, [
        'virustotal',
        'mobsf',
        'cape',
        'rampart_ai',
        'gemini',
      ]);
      expect(report.toolNotes['mobsf'], 'apk-only');
      expect(AnalysisReport.toolRouteKey('rampart_ai'), 'rampartai');
      expect(AnalysisReport.toolRouteKey('virustotal'), 'virustotal');
    });

    test('keeps Gemini data embedded in the main task report', () {
      final report = AnalysisReport.fromJson({
        'task_id': 'task-1',
        'analysis_summary': 'No malicious detections were reported.',
        'recommendation': 'General recommendation.',
        'gemini_recommendation': 'Gemini-specific recommendation.',
        'threat_assessment': 'Low threat.',
        'behavior': 'No suspicious behavior observed.',
        'risk_level': 'Caution',
      });

      expect(AnalysisReport.usesEmbeddedReport('gemini'), isTrue);
      expect(AnalysisReport.usesEmbeddedReport('virustotal'), isFalse);
      expect(report.analysisSummary, 'No malicious detections were reported.');
      expect(report.geminiRecommendation, 'Gemini-specific recommendation.');
      expect(report.threatAssessment, 'Low threat.');
      expect(report.behavior, 'No suspicious behavior observed.');
      expect(report.riskLevel, 'Caution');
    });

    test('parses progress and terminal task status', () {
      final result = TaskStatusResult.fromJson({
        'success': true,
        'task_id': 'task-1',
        'status': 'success',
        'progress': {
          'stage': 'complete',
          'tools': {
            'virustotal': {'status': 'success', 'score': 10},
            'mobsf': {'status': 'completed', 'score': 44.5},
            'rampart_ai': {'status': 'skipped'},
          },
        },
        'report': {'task_id': 'task-1', 'score': 44.5},
      });

      expect(result.isSuccess, isTrue);
      expect(result.isFailed, isFalse);
      expect(result.taskStatus, AnalysisTaskStatus.success);
      expect(result.progress?.stage, 'complete');
      expect(
        result.progress?.tool('virustotal')?.status,
        ToolRunStatus.completed,
      );
      expect(result.progress?.tool('mobsf')?.score, 44.5);
      expect(
        result.progress?.tool('rampart_ai')?.status,
        ToolRunStatus.skipped,
      );
      expect(result.report?.score, 44.5);
    });

    test('parses a paginated history page and its report scores', () {
      final page = AnalysisHistoryPage.fromJson({
        'success': true,
        'data': [
          {
            'aid': 'a-1',
            'task_id': 'task-1',
            'status': 'success',
            'file_name': 'demo.apk',
            'file_type': 'apk',
            'tools': 'virustotal,mobsf',
            'report': {
              'score': 81,
              'risk_level': 'Critical',
              'virustotal_score': 100,
              'mobsf_score': 62.5,
            },
          },
        ],
        'pagination': {
          'page': 1,
          'limit': 10,
          'total': 1,
          'total_pages': 1,
          'has_next': false,
          'has_prev': false,
        },
      });

      expect(page.success, isTrue);
      expect(page.items, hasLength(1));
      expect(page.items.single.fileName, 'demo.apk');
      expect(page.items.single.score, 81);
      expect(page.items.single.virustotalScore, 100);
      expect(page.items.single.mobsfScore, 62.5);
      expect(page.pagination?.hasNext, isFalse);
    });
  });
}

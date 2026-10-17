/// The host side of integration_test/perf_test.dart. When the test is done on the device, it writes
/// each traced action's timeline and summary to build/ (`<action>.timeline.json`,
/// `<action>.timeline_summary.json`), the figures below to build/perf_summary.json, and prints them.
/// How to run it: validation.md, "On-device timing".
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// The actions perf_test.dart traces, in order.
const _actions = ['cold_start', 'scroll_transactions', 'sms_first_read'];

/// Frame build (UI thread) and raster times in ms, and frames over budget (16 ms at 60 Hz).
const _figures = {
  'frame_count': 'frames',
  'average_frame_build_time_millis': 'build avg',
  '90th_percentile_frame_build_time_millis': 'p90',
  '99th_percentile_frame_build_time_millis': 'p99',
  'worst_frame_build_time_millis': 'worst',
  'missed_frame_build_budget_count': 'missed',
  'average_frame_rasterizer_time_millis': 'raster avg',
  '90th_percentile_frame_rasterizer_time_millis': 'p90',
  '99th_percentile_frame_rasterizer_time_millis': 'p99',
  'worst_frame_rasterizer_time_millis': 'worst',
  'missed_frame_rasterizer_budget_count': 'missed',
};

String _cell(Object? v) => switch (v) {
  final double d => d.toStringAsFixed(1),
  null => '-',
  _ => '$v',
};

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 30),
  responseDataCallback: (data) async {
    if (data == null) return;
    final report = <String, Object?>{'wall_clock_ms': data['wall_clock_ms'], 'counts': data['counts']};
    final table = StringBuffer()
      ..writeln()
      ..writeln('${'action'.padRight(22)}${[for (final f in _figures.values) f.padLeft(11)].join()}');
    for (final action in _actions) {
      final timeline = data[action];
      if (timeline is! Map<String, dynamic>) continue;
      final summary = driver.TimelineSummary.summarize(driver.Timeline.fromJson(timeline));
      await summary.writeTimelineToFile(action, pretty: true);
      final figures = {for (final key in _figures.keys) key: summary.summaryJson[key]};
      report[action] = figures;
      table.writeln('${action.padRight(22)}${[for (final v in figures.values) _cell(v).padLeft(11)].join()}');
    }
    table
      ..writeln()
      ..writeln('Wall clock (ms): ${data['wall_clock_ms']}')
      ..writeln('Counts: ${data['counts']}');
    File('${driver.testOutputsDirectory}/perf_summary.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    stdout.write(table);
  },
);

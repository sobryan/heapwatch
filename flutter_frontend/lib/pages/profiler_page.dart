import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jvm.dart';
import '../providers/jvm_provider.dart';
import '../providers/profiler_provider.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/status_badge.dart';
import 'package:web/web.dart' as web;

class ProfilerPage extends StatefulWidget {
  const ProfilerPage({super.key});

  @override
  State<ProfilerPage> createState() => _ProfilerPageState();
}

class _ProfilerPageState extends State<ProfilerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfilerProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    // Don't stop polling in dispose since provider outlives page
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jvmProvider = context.watch<JvmProvider>();
    final profiler = context.watch<ProfilerProvider>();
    final selectedJvm = jvmProvider.selectedJvm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Profiler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Start Recording Panel
          _buildPanel(
            title: 'Start Recording',
            child: selectedJvm != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              color: textSecondary, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Target: '),
                            TextSpan(
                              text: selectedJvm.displayName,
                              style: const TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' (PID ${selectedJvm.pid})'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Profile:',
                            style: TextStyle(
                                fontSize: 13, color: textSecondary),
                          ),
                          ...['CPU', 'ALLOC', 'FULL'].map((t) =>
                              _profileTypeButton(t, profiler)),
                          const SizedBox(width: 8),
                          const Text(
                            'Duration:',
                            style: TextStyle(
                                fontSize: 13, color: textSecondary),
                          ),
                          SizedBox(
                            width: 80,
                            height: 32,
                            child: TextField(
                              controller: TextEditingController(
                                  text: '${profiler.duration}'),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                  fontSize: 13, color: textColor),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                              ),
                              onSubmitted: (v) {
                                final dur = int.tryParse(v);
                                if (dur != null && dur >= 5 && dur <= 300) {
                                  profiler.setDuration(dur);
                                }
                              },
                            ),
                          ),
                          const Text(
                            'sec',
                            style: TextStyle(
                                fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: profiler.loading
                                ? null
                                : () => profiler.startJfr(selectedJvm),
                            icon: profiler.loading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: bgColor),
                                  )
                                : const Icon(Icons.fiber_manual_record,
                                    size: 14),
                            label: const Text('Start JFR Recording'),
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: bgColor,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: profiler.loading
                                ? null
                                : () =>
                                    profiler.triggerHeapDump(selectedJvm),
                            icon: const Icon(Icons.memory, size: 14),
                            label: const Text('Heap Dump'),
                            style: FilledButton.styleFrom(
                              backgroundColor: redColor,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: profiler.diagnosingPid == selectedJvm.pid
                                ? null
                                : () => profiler.runDiagnosis(selectedJvm.pid),
                            icon: profiler.diagnosingPid == selectedJvm.pid
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.health_and_safety, size: 14),
                            label: const Text('Diagnose'),
                            style: FilledButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Text(
                    'Select a JVM from the sidebar to start profiling.',
                    style: TextStyle(color: textSecondary),
                  ),
          ),
          const SizedBox(height: 24),

          // JFR Recordings Table
          _buildPanel(
            title: 'JFR Recordings',
            child: profiler.recordings.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No recordings yet.',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        color: textColor,
                        fontSize: 13,
                      ),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Process')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Duration')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Size')),
                        DataColumn(label: Text('Started')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: profiler.recordings.map((r) {
                        return DataRow(cells: [
                          DataCell(Text('${r.processName} (PID ${r.pid})')),
                          DataCell(Text(r.profileType)),
                          DataCell(Text('${r.durationSeconds}s')),
                          DataCell(StatusBadge(status: r.status)),
                          DataCell(Text(r.fileSizeBytes > 0
                              ? formatBytes(r.fileSizeBytes)
                              : '\u2014')),
                          DataCell(Text(timeAgo(r.startTime))),
                          DataCell(_recordingActions(r, profiler)),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // Heap Dumps Table
          _buildPanel(
            title: 'Heap Dumps',
            child: profiler.heapDumps.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No heap dumps yet.',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        color: textColor,
                        fontSize: 13,
                      ),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Process')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Size')),
                        DataColumn(label: Text('Created')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: profiler.heapDumps.map((d) {
                        return DataRow(cells: [
                          DataCell(Text('${d.processName} (PID ${d.pid})')),
                          DataCell(StatusBadge(status: d.status)),
                          DataCell(Text(d.fileSizeBytes > 0
                              ? formatBytes(d.fileSizeBytes)
                              : '\u2014')),
                          DataCell(Text(timeAgo(d.createdAt))),
                          DataCell(_heapDumpActions(d, profiler)),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),

          // JFR Analysis Results
          ...profiler.recordings
              .where((r) => profiler.getJfrAnalysis(r.id) != null)
              .map((r) {
            final analysis = profiler.getJfrAnalysis(r.id)!;
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildJfrAnalysisPanel(analysis),
            );
          }),

          // Heap Dump Analysis Results
          ...profiler.heapDumps
              .where((d) => profiler.getHeapDumpAnalysis(d.id) != null)
              .map((d) {
            final analysis = profiler.getHeapDumpAnalysis(d.id)!;
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildHeapDumpAnalysisPanel(analysis),
            );
          }),

          // Diagnosis Report
          if (selectedJvm != null && profiler.getDiagnosisReport(selectedJvm.pid) != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildDiagnosisPanel(profiler.getDiagnosisReport(selectedJvm.pid)!),
            ),

          // Analysis error
          if (profiler.analysisError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: redColor.withValues(alpha: 0.1),
                  border: Border.all(color: redColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profiler.analysisError!,
                  style: const TextStyle(color: redColor, fontSize: 13),
                ),
              ),
            ),

          // Diagnosis error
          if (profiler.diagnosisError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: redColor.withValues(alpha: 0.1),
                  border: Border.all(color: redColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profiler.diagnosisError!,
                  style: const TextStyle(color: redColor, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heapDumpActions(HeapDump d, ProfilerProvider profiler) {
    if (d.status != 'COMPLETED') return const SizedBox.shrink();
    final isAnalyzing = profiler.analysisLoading == d.id;
    final hasAnalysis = profiler.getHeapDumpAnalysis(d.id) != null;
    return FilledButton.icon(
      onPressed: isAnalyzing ? null : () => profiler.fetchHeapDumpAnalysis(d.id),
      icon: isAnalyzing
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(hasAnalysis ? Icons.refresh : Icons.analytics, size: 14),
      label: Text(hasAnalysis ? 'Re-analyze' : 'Analyze'),
      style: FilledButton.styleFrom(
        backgroundColor: hasAnalysis ? surface2Color : greenColor,
        foregroundColor: hasAnalysis ? textColor : bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 28),
      ),
    );
  }

  Widget _buildJfrAnalysisPanel(JfrAnalysis analysis) {
    return _buildPanel(
      title: 'JFR Analysis: ${analysis.processName} (${analysis.profileType})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CPU Hotspots - Horizontal Bar Chart
          if (analysis.cpuHotspots.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: cyanColor, size: 16),
                const SizedBox(width: 6),
                const Text('CPU Hotspots',
                    style: TextStyle(
                        color: cyanColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            ...analysis.cpuHotspots.take(10).map((h) {
              if (h.note != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(h.note!,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 12)),
                );
              }
              if (h.error != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(h.error!,
                      style: const TextStyle(color: redColor, fontSize: 12)),
                );
              }
              final maxSamples = analysis.cpuHotspots
                  .where((x) => x.samples > 0)
                  .fold(1, (m, x) => math.max(m, x.samples));
              final fraction = maxSamples > 0 ? h.samples / maxSamples : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text('${h.samples}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(h.method ?? '',
                              style: const TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 58),
                      child: _buildHorizontalBar(fraction, cyanColor),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Allocation Hotspots - Horizontal Bar Chart
          if (analysis.allocationHotspots.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.memory, color: purpleColor, size: 16),
                const SizedBox(width: 6),
                const Text('Allocation Hotspots',
                    style: TextStyle(
                        color: purpleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            ...analysis.allocationHotspots.take(10).map((a) {
              if (a.note != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(a.note!,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 12)),
                );
              }
              final maxBytes = analysis.allocationHotspots
                  .where((x) => x.totalBytes > 0)
                  .fold(1, (m, x) => math.max(m, x.totalBytes));
              final fraction = maxBytes > 0 ? a.totalBytes / maxBytes : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(a.totalFormatted ?? formatBytes(a.totalBytes),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: purpleColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(a.className ?? '',
                              style: const TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Text('${a.allocationCount} allocs',
                            style: const TextStyle(
                                color: textSecondary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 78),
                      child: _buildHorizontalBar(fraction, purpleColor),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Thread Activity + GC Summary side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMiniSection('Thread Activity', [
                  if (analysis.threadActivity.containsKey('error'))
                    Text(analysis.threadActivity['error'],
                        style:
                            const TextStyle(color: redColor, fontSize: 12))
                  else ...[
                    _kvRow('Starts',
                        '${analysis.threadActivity['threadStarts'] ?? analysis.threadActivity['totalThreads'] ?? 0}'),
                    _kvRow('Ends',
                        '${analysis.threadActivity['threadEnds'] ?? analysis.threadActivity['runnable'] ?? 0}'),
                    if (analysis.threadActivity.containsKey('threadSleepEvents'))
                      _kvRow('Sleeps',
                          '${analysis.threadActivity['threadSleepEvents']}'),
                    if (analysis.threadActivity.containsKey('threadParkEvents'))
                      _kvRow('Parks',
                          '${analysis.threadActivity['threadParkEvents']}'),
                    if (analysis.threadActivity.containsKey('waiting'))
                      _kvRow('Waiting',
                          '${analysis.threadActivity['waiting']}'),
                    if (analysis.threadActivity.containsKey('blocked'))
                      _kvRow('Blocked',
                          '${analysis.threadActivity['blocked']}'),
                  ],
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildMiniSection('GC Summary', [
                  if (analysis.gcSummary.containsKey('error'))
                    Text(analysis.gcSummary['error'],
                        style:
                            const TextStyle(color: redColor, fontSize: 12))
                  else ...[
                    _kvRow('Collections',
                        '${analysis.gcSummary['collectionCount'] ?? 0}'),
                    _kvRow('Total Pause',
                        '${analysis.gcSummary['totalPauseMs'] ?? 0} ms'),
                    _kvRow('Max Pause',
                        '${analysis.gcSummary['maxPauseMs'] ?? 0} ms'),
                    _kvRow('Avg Pause',
                        '${analysis.gcSummary['avgPauseMs'] ?? 0} ms'),
                    if (analysis.gcSummary['lastCause'] != null)
                      _kvRow('Last Cause',
                          '${analysis.gcSummary['lastCause']}'),
                  ],
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeapDumpAnalysisPanel(HeapDumpAnalysis analysis) {
    return _buildPanel(
      title:
          'Heap Dump Analysis: ${analysis.processName} (${analysis.fileSizeFormatted})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Row(
            children: [
              _buildMiniStat('Classes', '${analysis.summary['totalClassesAnalyzed'] ?? 0}'),
              const SizedBox(width: 16),
              _buildMiniStat('Instances', _compactNumber(analysis.summary['totalInstances'] ?? 0)),
              const SizedBox(width: 16),
              _buildMiniStat('Total Size', analysis.summary['totalBytesFormatted'] ?? ''),
            ],
          ),
          const SizedBox(height: 16),

          // Top Objects Table with visual size bars
          Row(
            children: [
              const Icon(Icons.storage, color: cyanColor, size: 16),
              const SizedBox(width: 6),
              const Text('Top Objects by Size',
                  style: TextStyle(
                      color: cyanColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ...() {
            final items = analysis.topObjectsBySize
                .where((o) => o.note == null && o.error == null)
                .take(20)
                .toList();
            final maxObjBytes = items.fold(1, (m, o) => math.max(m, o.bytes));
            return items.map((o) {
              final fraction = maxObjBytes > 0 ? o.bytes / maxObjBytes : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${o.rank}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: textSecondary, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(o.className,
                          style: const TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(_compactNumber(o.instances),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: textSecondary, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 65,
                      child: Text(o.bytesFormatted ?? formatBytes(o.bytes),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildHorizontalBar(fraction, cyanColor),
                    ),
                  ],
                ),
              );
            });
          }(),
          const SizedBox(height: 16),

          // Leak Suspects
          const Text('Leak Suspects',
              style: TextStyle(
                  color: yellowColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 8),
          ...analysis.leakSuspects.map((s) {
            final severityColor = s.severity == 'HIGH'
                ? redColor
                : s.severity == 'MEDIUM'
                    ? yellowColor
                    : textSecondary;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.08),
                border: Border.all(
                    color: severityColor.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(status: s.severity),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.className,
                            style: const TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(s.reason,
                      style:
                          const TextStyle(color: textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(s.recommendation,
                      style: TextStyle(
                          color: primaryColor.withValues(alpha: 0.8),
                          fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(key,
                style: const TextStyle(color: textSecondary, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  String _compactNumber(dynamic n) {
    final num val = n is num ? n : 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }

  Widget _profileTypeButton(String type, ProfilerProvider profiler) {
    final active = profiler.profileType == type;
    return OutlinedButton(
      onPressed: () => profiler.setProfileType(type),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            active ? primaryColor : Colors.transparent,
        foregroundColor: active ? bgColor : primaryColor,
        side: const BorderSide(color: primaryColor),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 30),
      ),
      child: Text(type),
    );
  }

  Widget _recordingActions(dynamic r, ProfilerProvider profiler) {
    if (r.status == 'COMPLETED') {
      final isAnalyzing = profiler.analysisLoading == r.id;
      final hasAnalysis = profiler.getJfrAnalysis(r.id) != null;
      return Wrap(
        spacing: 6,
        children: [
          OutlinedButton(
            onPressed: () {
              web.window.open(profiler.downloadUrl(r.id), '_blank');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: const Size(0, 28),
            ),
            child: const Text('Download'),
          ),
          FilledButton.icon(
            onPressed: isAnalyzing
                ? null
                : () => profiler.fetchJfrAnalysis(r.id),
            icon: isAnalyzing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    hasAnalysis ? Icons.refresh : Icons.analytics,
                    size: 14),
            label: Text(hasAnalysis ? 'Re-analyze' : 'Analyze'),
            style: FilledButton.styleFrom(
              backgroundColor: hasAnalysis ? surface2Color : greenColor,
              foregroundColor: hasAnalysis ? textColor : bgColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              minimumSize: const Size(0, 28),
            ),
          ),
        ],
      );
    }
    if (r.status == 'RECORDING') {
      return FilledButton(
        onPressed: () => profiler.cancelRecording(r.id),
        style: FilledButton.styleFrom(
          backgroundColor: redColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: const Size(0, 28),
        ),
        child: const Text('Cancel'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHorizontalBar(double fraction, Color color) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosisPanel(DiagnosisReport report) {
    final healthColor = report.healthScore >= 80
        ? greenColor
        : report.healthScore >= 50
            ? yellowColor
            : redColor;

    return _buildPanel(
      title: 'Diagnosis: ${report.processName} (PID ${report.pid})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health score gauge
          Row(
            children: [
              // Health score circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: healthColor, width: 3),
                  color: healthColor.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    '${report.healthScore}',
                    style: TextStyle(
                      color: healthColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Score: ${report.healthScore}/100',
                      style: TextStyle(
                        color: healthColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.healthAssessment,
                      style: const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Snapshot stats
          if (report.snapshot != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildMiniStat('Heap', '${report.snapshot!.heapUsagePercent.toStringAsFixed(0)}%'),
                _buildMiniStat('Threads', '${report.snapshot!.threadCount}'),
                _buildMiniStat('Status', report.snapshot!.status),
                _buildMiniStat('GC Count', '${report.snapshot!.gcCollectionCount}'),
              ],
            ),
          ],

          // Issues
          if (report.issues.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.error_outline, color: redColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Issues Found (${report.issues.length})',
                  style: const TextStyle(
                    color: redColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...report.issues.map((issue) {
              final severityColor = issue.severity == 'CRITICAL'
                  ? redColor
                  : issue.severity == 'WARNING'
                      ? yellowColor
                      : textSecondary;
              final categoryIcon = switch (issue.category) {
                'MEMORY' => Icons.memory,
                'CPU' => Icons.speed,
                'THREADS' => Icons.account_tree,
                'GC' => Icons.delete_sweep,
                _ => Icons.info_outline,
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.08),
                  border: Border.all(color: severityColor.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(categoryIcon, size: 14, color: severityColor),
                        const SizedBox(width: 6),
                        StatusBadge(status: issue.severity),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue.title,
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Impact: ${issue.impactScore}/10',
                            style: TextStyle(
                              color: severityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.description,
                      style: const TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    if (issue.affectedMethod != null && issue.affectedMethod!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Method: ${issue.affectedMethod}',
                        style: const TextStyle(
                          color: cyanColor,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],

          // Recommendations
          if (report.recommendations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: yellowColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Recommendations (${report.recommendations.length})',
                  style: const TextStyle(
                    color: yellowColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...report.recommendations.map((rec) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.description,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  if (rec.affectedMethod != null && rec.affectedMethod!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Method: ${rec.affectedMethod}',
                      style: const TextStyle(
                        color: cyanColor,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  if (rec.suggestedFix != null && rec.suggestedFix!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        rec.suggestedFix!,
                        style: const TextStyle(
                          color: greenColor,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  if (rec.estimatedImpact != null && rec.estimatedImpact!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expected impact: ${rec.estimatedImpact}',
                      style: TextStyle(
                        color: primaryColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            )),
          ],

          // Timestamp
          const SizedBox(height: 12),
          Text(
            'Diagnosed: ${timeAgo(report.timestamp)}',
            style: const TextStyle(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

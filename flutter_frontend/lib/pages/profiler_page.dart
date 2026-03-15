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
                          FilledButton.icon(
                            onPressed: profiler.threadAnalysisPid == selectedJvm.pid
                                ? null
                                : () => profiler.fetchThreadAnalysis(selectedJvm.pid),
                            icon: profiler.threadAnalysisPid == selectedJvm.pid
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.account_tree, size: 14),
                            label: const Text('Threads'),
                            style: FilledButton.styleFrom(
                              backgroundColor: cyanColor,
                              foregroundColor: bgColor,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: profiler.gcAnalysisPid == selectedJvm.pid
                                ? null
                                : () => profiler.fetchGcAnalysis(selectedJvm.pid),
                            icon: profiler.gcAnalysisPid == selectedJvm.pid
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.delete_sweep, size: 14),
                            label: const Text('GC'),
                            style: FilledButton.styleFrom(
                              backgroundColor: yellowColor,
                              foregroundColor: bgColor,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: profiler.snapshotLoading
                                ? null
                                : () {
                                    profiler.captureSnapshot(selectedJvm.pid);
                                  },
                            icon: profiler.snapshotLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt, size: 14),
                            label: const Text('Snapshot'),
                            style: FilledButton.styleFrom(
                              backgroundColor: greenColor,
                              foregroundColor: bgColor,
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

          // Thread Analysis
          if (selectedJvm != null && profiler.getThreadAnalysis(selectedJvm.pid) != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildThreadAnalysisPanel(profiler.getThreadAnalysis(selectedJvm.pid)!),
            ),

          // GC Analysis
          if (selectedJvm != null && profiler.getGcAnalysis(selectedJvm.pid) != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildGcAnalysisPanel(profiler.getGcAnalysis(selectedJvm.pid)!),
            ),

          // Snapshots and Comparison
          if (selectedJvm != null && profiler.getSnapshots(selectedJvm.pid).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildSnapshotsPanel(selectedJvm.pid, profiler),
            ),

          // Comparison Result
          if (profiler.comparisonResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildComparisonPanel(profiler.comparisonResult!),
            ),

          // Thread analysis error
          if (profiler.threadAnalysisError != null)
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
                  profiler.threadAnalysisError!,
                  style: const TextStyle(color: redColor, fontSize: 13),
                ),
              ),
            ),

          // GC analysis error
          if (profiler.gcAnalysisError != null)
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
                  profiler.gcAnalysisError!,
                  style: const TextStyle(color: redColor, fontSize: 13),
                ),
              ),
            ),

          // Snapshot error
          if (profiler.snapshotError != null)
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
                  profiler.snapshotError!,
                  style: const TextStyle(color: redColor, fontSize: 13),
                ),
              ),
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

  Widget _buildThreadAnalysisPanel(Map<String, dynamic> analysis) {
    if (analysis.containsKey('error')) {
      return _buildPanel(
        title: 'Thread Analysis',
        child: Text(analysis['error'].toString(),
            style: const TextStyle(color: redColor, fontSize: 13)),
      );
    }

    final stateDistribution = Map<String, dynamic>.from(analysis['stateDistribution'] ?? {});
    final deadlocks = (analysis['deadlocks'] as List? ?? []);
    final blockedChains = (analysis['blockedChains'] as List? ?? []);
    final lockContention = (analysis['lockContention'] as List? ?? []);
    final topFrames = (analysis['topStackFrames'] as List? ?? []);
    final totalThreads = analysis['totalThreads'] ?? 0;

    return _buildPanel(
      title: 'Thread Analysis ($totalThreads threads)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State Distribution - colored bars
          const Text('Thread State Distribution',
              style: TextStyle(color: cyanColor, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          ...stateDistribution.entries.map((entry) {
            final state = entry.key;
            final count = (entry.value as num).toInt();
            final total = totalThreads > 0 ? totalThreads : 1;
            final fraction = count / total;
            final color = switch (state) {
              'RUNNABLE' => greenColor,
              'BLOCKED' => redColor,
              'WAITING' => const Color(0xFF3B82F6),
              'TIMED_WAITING' => yellowColor,
              _ => textSecondary,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(state,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('$count',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: textColor, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: surface2Color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Deadlock warnings
          if (deadlocks.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: redColor.withValues(alpha: 0.1),
                border: Border.all(color: redColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: redColor, size: 16),
                      const SizedBox(width: 8),
                      Text('${deadlocks.length} Deadlock(s) Detected!',
                          style: const TextStyle(color: redColor, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...deadlocks.map((dl) {
                    final d = Map<String, dynamic>.from(dl);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(d['message']?.toString() ?? '',
                          style: const TextStyle(color: textColor, fontSize: 12)),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Blocked chains
          if (blockedChains.isNotEmpty) ...[
            const Text('Blocked Thread Chains',
                style: TextStyle(color: yellowColor, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...blockedChains.map((bc) {
              final chain = Map<String, dynamic>.from(bc);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: yellowColor.withValues(alpha: 0.08),
                  border: Border.all(color: yellowColor.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: chain['blockedThread'] ?? '', style: const TextStyle(color: redColor, fontWeight: FontWeight.w600, fontSize: 12)),
                        const TextSpan(text: ' blocked by ', style: TextStyle(color: textSecondary, fontSize: 12)),
                        TextSpan(text: chain['blockedBy'] ?? '', style: const TextStyle(color: cyanColor, fontWeight: FontWeight.w600, fontSize: 12)),
                      ]),
                    ),
                    if (chain['blockedAt'] != null)
                      Text('at ${chain['blockedAt']}',
                          style: const TextStyle(color: textSecondary, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Lock contention
          if (lockContention.isNotEmpty) ...[
            const Text('Lock Contention',
                style: TextStyle(color: purpleColor, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...lockContention.map((lc) {
              final lock = Map<String, dynamic>.from(lc);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${lock['waitingThreads']} waiting',
                        style: const TextStyle(color: redColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('Lock ${lock['lockAddress']}',
                        style: const TextStyle(color: textSecondary, fontSize: 11, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    Text('owned by ${lock['owner']}',
                        style: const TextStyle(color: cyanColor, fontSize: 11)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Top stack frames
          if (topFrames.isNotEmpty) ...[
            const Text('Top Stack Frames',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...topFrames.take(10).map((tf) {
              final frame = Map<String, dynamic>.from(tf);
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('${frame['count']}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(frame['method']?.toString() ?? '',
                          style: const TextStyle(color: textColor, fontSize: 11, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildGcAnalysisPanel(Map<String, dynamic> analysis) {
    if (analysis.containsKey('error')) {
      return _buildPanel(
        title: 'GC Analysis',
        child: Text(analysis['error'].toString(),
            style: const TextStyle(color: redColor, fontSize: 13)),
      );
    }

    return _buildPanel(
      title: 'GC Analysis (PID ${analysis['pid']})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMiniStat('GC Type', analysis['gcType']?.toString() ?? 'Unknown'),
              _buildMiniStat('Total GCs', '${analysis['totalCollections'] ?? 0}'),
              _buildMiniStat('Avg Pause', '${analysis['avgPauseMs'] ?? 0} ms'),
              _buildMiniStat('Max Pause', '${analysis['maxPauseEstimateMs'] ?? 0} ms'),
              _buildMiniStat('Throughput', '${analysis['throughputPercent'] ?? 99}%'),
            ],
          ),
          const SizedBox(height: 16),

          // Young vs Old gen breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMiniSection('Young Generation', [
                  _kvRow('Collections', '${analysis['youngGenCollections'] ?? 0}'),
                  _kvRow('Total Pause', '${analysis['youngGenPauseMs'] ?? 0} ms'),
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildMiniSection('Old Generation', [
                  _kvRow('Collections', '${analysis['oldGenCollections'] ?? 0}'),
                  _kvRow('Total Pause', '${analysis['oldGenPauseMs'] ?? 0} ms'),
                ]),
              ),
            ],
          ),

          // GC Pause distribution as a simple bar
          const SizedBox(height: 16),
          const Text('Pause Time Distribution',
              style: TextStyle(color: cyanColor, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          _buildGcPauseBar(analysis),
        ],
      ),
    );
  }

  Widget _buildGcPauseBar(Map<String, dynamic> analysis) {
    final youngMs = ((analysis['youngGenPauseMs'] ?? 0) as num).toDouble();
    final oldMs = ((analysis['oldGenPauseMs'] ?? 0) as num).toDouble();
    final total = youngMs + oldMs;
    if (total <= 0) {
      return const Text('No GC pauses recorded.', style: TextStyle(color: textSecondary, fontSize: 12));
    }
    final youngFraction = youngMs / total;
    final oldFraction = oldMs / total;

    return Column(
      children: [
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (youngFraction * 100).round().clamp(1, 100),
                child: Container(
                  decoration: BoxDecoration(
                    color: greenColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(4),
                      bottomLeft: const Radius.circular(4),
                      topRight: oldFraction > 0 ? Radius.zero : const Radius.circular(4),
                      bottomRight: oldFraction > 0 ? Radius.zero : const Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: Text('Young ${youngMs.toStringAsFixed(0)}ms',
                        style: const TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              if (oldFraction > 0)
                Expanded(
                  flex: (oldFraction * 100).round().clamp(1, 100),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: yellowColor,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Center(
                      child: Text('Old ${oldMs.toStringAsFixed(0)}ms',
                          style: const TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('Total pause: ${total.toStringAsFixed(0)} ms',
            style: const TextStyle(color: textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildSnapshotsPanel(int pid, ProfilerProvider profiler) {
    final snapshots = profiler.getSnapshots(pid);

    return _buildPanel(
      title: 'Snapshots (${snapshots.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshots.length >= 2) ...[
            const Text('Select two snapshots to compare:',
                style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < snapshots.length && i < 10; i++)
                  _snapshotChip(snapshots[i], profiler, snapshots),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                  color: textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
              dataTextStyle: const TextStyle(color: textColor, fontSize: 12),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Time')),
                DataColumn(label: Text('Heap')),
                DataColumn(label: Text('Threads')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('GC Count')),
              ],
              rows: snapshots.take(10).map((snap) {
                return DataRow(cells: [
                  DataCell(Text('#${snap['id']}')),
                  DataCell(Text(timeAgo(snap['timestamp']?.toString()))),
                  DataCell(Text('${((snap['heapUsagePercent'] ?? 0) as num).toStringAsFixed(1)}%')),
                  DataCell(Text('${snap['threadCount'] ?? 0}')),
                  DataCell(StatusBadge(status: snap['status']?.toString() ?? 'HEALTHY')),
                  DataCell(Text('${snap['gcCollectionCount'] ?? 0}')),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _snapshotChip(Map<String, dynamic> snap, ProfilerProvider profiler, List<Map<String, dynamic>> allSnapshots) {
    return ActionChip(
      label: Text('#${snap['id']} (${timeAgo(snap['timestamp']?.toString())})',
          style: const TextStyle(fontSize: 11)),
      backgroundColor: surface2Color,
      onPressed: () {
        // If there's already a comparison, clear it; otherwise compare with the first different snapshot
        if (allSnapshots.length >= 2) {
          final otherIdx = allSnapshots.indexOf(snap) == 0 ? 1 : 0;
          final otherId = (allSnapshots[otherIdx]['id'] as num).toInt();
          final thisId = (snap['id'] as num).toInt();
          profiler.compareSnapshots(thisId, otherId);
        }
      },
    );
  }

  Widget _buildComparisonPanel(Map<String, dynamic> comparison) {
    final snap1 = Map<String, dynamic>.from(comparison['snapshot1'] ?? {});
    final snap2 = Map<String, dynamic>.from(comparison['snapshot2'] ?? {});
    final deltas = Map<String, dynamic>.from(comparison['deltas'] ?? {});
    final trend = deltas['overallTrend']?.toString() ?? 'STABLE';
    final trendColor = trend == 'IMPROVING' ? greenColor : trend == 'DEGRADING' ? redColor : textSecondary;

    return _buildPanel(
      title: 'Comparison: Snapshot #${snap1['id']} vs #${snap2['id']}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall trend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.1),
              border: Border.all(color: trendColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  trend == 'IMPROVING' ? Icons.trending_up : trend == 'DEGRADING' ? Icons.trending_down : Icons.trending_flat,
                  color: trendColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text('Overall: $trend',
                    style: TextStyle(color: trendColor, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Delta details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _deltaRow('Heap Used', deltas['heapUsedChangeFormatted']?.toString() ?? '0',
                        ((deltas['heapUsedChange'] ?? 0) as num).toDouble()),
                    _deltaRow('Heap %', '${((deltas['heapPercentChange'] ?? 0) as num).toStringAsFixed(1)}%',
                        ((deltas['heapPercentChange'] ?? 0) as num).toDouble()),
                    _deltaRow('Threads', '${deltas['threadCountChange'] ?? 0}',
                        ((deltas['threadCountChange'] ?? 0) as num).toDouble()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _deltaRow('GC Count', '+${deltas['gcCountChange'] ?? 0}',
                        ((deltas['gcCountChange'] ?? 0) as num).toDouble()),
                    _deltaRow('GC Time', '+${deltas['gcTimeChangeMs'] ?? 0} ms',
                        ((deltas['gcTimeChangeMs'] ?? 0) as num).toDouble()),
                    if (deltas['statusChanged'] == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Status', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ),
                            StatusBadge(status: deltas['statusBefore'] ?? ''),
                            const Text(' -> ', style: TextStyle(color: textSecondary, fontSize: 12)),
                            StatusBadge(status: deltas['statusAfter'] ?? ''),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deltaRow(String label, String value, double numValue) {
    final isPositive = numValue > 0;
    final isNegative = numValue < 0;
    // For heap/threads, increase = bad (red), decrease = good (green)
    final color = isPositive ? redColor : isNegative ? greenColor : textSecondary;
    final icon = isPositive ? Icons.arrow_upward : isNegative ? Icons.arrow_downward : Icons.remove;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
          ),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
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

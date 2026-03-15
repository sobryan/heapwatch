import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jvm.dart';
import '../providers/jvm_provider.dart';
import '../providers/alert_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/sparkline.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int tabIndex)? onTabSwitch;
  const DashboardPage({super.key, this.onTabSwitch});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  MetricsHistory? _history;
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  void _loadTrends() async {
    final jvmProvider = context.read<JvmProvider>();
    final selectedJvm = jvmProvider.selectedJvm;
    if (selectedJvm == null && jvmProvider.jvms.isEmpty) return;

    final targetPid = selectedJvm?.pid ?? (jvmProvider.jvms.isNotEmpty ? jvmProvider.jvms.first.pid : null);
    if (targetPid == null) return;

    setState(() => _loadingHistory = true);
    try {
      final api = context.read<ApiService>();
      final history = await api.getMetricsHistory(targetPid);
      if (mounted) {
        setState(() {
          _history = history;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JvmProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final jvms = provider.jvms;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900
                  ? 5
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  StatCard(
                    value: '${jvms.length}',
                    label: 'JVM Processes',
                  ),
                  StatCard(
                    value: '${provider.healthyCount}',
                    label: 'Healthy',
                    valueColor: greenColor,
                  ),
                  StatCard(
                    value: '${provider.needsAttentionCount}',
                    label: 'Needs Attention',
                    valueColor:
                        provider.criticalCount > 0 ? redColor : yellowColor,
                  ),
                  StatCard(
                    value: formatBytes(provider.totalHeapUsed),
                    label: 'Total Heap Used',
                  ),
                  StatCard(
                    value: '${provider.totalThreads}',
                    label: 'Total Threads',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Active Alerts Section
          if (alertProvider.alerts.isNotEmpty) ...[
            _buildAlertsPanel(alertProvider),
            const SizedBox(height: 24),
          ],

          // Trends Section
          _buildTrendsPanel(provider),
          const SizedBox(height: 24),

          // JVM Table
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All JVM Processes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                if (jvms.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Discovering JVM processes...',
                            style: TextStyle(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
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
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Process')),
                        DataColumn(label: Text('PID')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Heap')),
                        DataColumn(label: Text('Threads')),
                        DataColumn(label: Text('JVM Version')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: jvms.map((jvm) {
                        final heapText = jvm.heapMaxBytes > 0
                            ? '${formatBytes(jvm.heapUsedBytes)} / ${formatBytes(jvm.heapMaxBytes)} (${jvm.heapUsagePercent.toStringAsFixed(0)}%)'
                            : '\u2014';
                        final version = jvm.jvmVersion != null &&
                                jvm.jvmVersion!.length > 40
                            ? jvm.jvmVersion!.substring(0, 40)
                            : jvm.jvmVersion ?? '\u2014';

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                jvm.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              onTap: () => _selectJvm(context, jvm),
                            ),
                            DataCell(
                              Text(
                                '${jvm.pid}',
                                style:
                                    const TextStyle(color: textSecondary),
                              ),
                            ),
                            DataCell(StatusBadge(status: jvm.status)),
                            DataCell(Text(heapText)),
                            DataCell(Text(
                              jvm.threadCount > 0
                                  ? '${jvm.threadCount}'
                                  : '\u2014',
                            )),
                            DataCell(
                              Text(
                                version,
                                style: const TextStyle(
                                    fontSize: 12, color: textSecondary),
                              ),
                            ),
                            DataCell(
                              OutlinedButton(
                                onPressed: () =>
                                    _selectJvm(context, jvm),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: const BorderSide(
                                      color: primaryColor),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Inspect'),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsPanel(AlertProvider alertProvider) {
    final recentAlerts = alertProvider.alerts.take(10).toList();
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: yellowColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Active Alerts (${alertProvider.activeCount})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (alertProvider.alerts.isNotEmpty)
                TextButton(
                  onPressed: () => alertProvider.clearAlerts(),
                  style: TextButton.styleFrom(
                    foregroundColor: textSecondary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...recentAlerts.map((alert) {
            final severityColor = alert.severity == 'CRITICAL'
                ? redColor
                : alert.severity == 'WARNING'
                    ? yellowColor
                    : textSecondary;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.08),
                border: Border(
                  left: BorderSide(color: severityColor, width: 3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  StatusBadge(status: alert.severity),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.message,
                      style: const TextStyle(color: textColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo(alert.timestamp),
                    style: const TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrendsPanel(JvmProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Trends${_history != null ? ' - ${_history!.processName} (PID ${_history!.pid})' : ''}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadingHistory ? null : _loadTrends,
                icon: _loadingHistory
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_history == null || _history!.snapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Select a JVM and wait for data collection (15s intervals).',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final snapshots = _history!.snapshots;
                final heapData =
                    snapshots.map((s) => s.heapPercent).toList();
                final threadData =
                    snapshots.map((s) => s.threadCount.toDouble()).toList();
                final lastSnap = snapshots.last;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Sparkline(
                          data: heapData,
                          lineColor: _heapSparkColor(lastSnap.heapPercent),
                          label: 'Heap Usage',
                          currentValue:
                              '${lastSnap.heapPercent.toStringAsFixed(1)}%',
                          height: 80,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Sparkline(
                          data: threadData,
                          lineColor: cyanColor,
                          label: 'Thread Count',
                          currentValue: '${lastSnap.threadCount}',
                          height: 80,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Sparkline(
                        data: heapData,
                        lineColor: _heapSparkColor(lastSnap.heapPercent),
                        label: 'Heap Usage',
                        currentValue:
                            '${lastSnap.heapPercent.toStringAsFixed(1)}%',
                        height: 70,
                      ),
                      const SizedBox(height: 12),
                      Sparkline(
                        data: threadData,
                        lineColor: cyanColor,
                        label: 'Thread Count',
                        currentValue: '${lastSnap.threadCount}',
                        height: 70,
                      ),
                    ],
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Color _heapSparkColor(double percent) {
    if (percent > 85) return redColor;
    if (percent > 70) return yellowColor;
    return greenColor;
  }

  void _selectJvm(BuildContext context, jvm) {
    context.read<JvmProvider>().selectJvm(jvm);
    widget.onTabSwitch?.call(1); // Switch to profiler tab
  }
}

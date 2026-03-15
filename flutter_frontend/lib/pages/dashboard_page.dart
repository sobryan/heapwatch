import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jvm.dart';
import '../providers/jvm_provider.dart';
import '../providers/alert_provider.dart';
import '../providers/profiler_provider.dart';
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
  // Per-JVM metrics histories
  final Map<int, MetricsHistory> _jvmHistories = {};
  bool _loadingHistories = false;

  @override
  void initState() {
    super.initState();
    _loadAllTrends();
  }

  void _loadAllTrends() async {
    final jvmProvider = context.read<JvmProvider>();
    if (jvmProvider.jvms.isEmpty) return;

    setState(() => _loadingHistories = true);
    final api = context.read<ApiService>();

    for (final jvm in jvmProvider.jvms) {
      try {
        final history = await api.getMetricsHistory(jvm.pid);
        if (mounted) {
          _jvmHistories[jvm.pid] = history;
        }
      } catch (_) {
        // skip failed
      }
    }
    if (mounted) setState(() => _loadingHistories = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JvmProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final profiler = context.watch<ProfilerProvider>();
    final jvms = provider.jvms;

    // Compute system-level aggregates
    final activeRecordings = profiler.recordings
        .where((r) => r.status == 'RECORDING')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // System Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 1100
                  ? 6
                  : constraints.maxWidth > 800
                      ? 4
                      : constraints.maxWidth > 500
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
                  StatCard(
                    value: '${alertProvider.activeCount}',
                    label: 'Active Alerts',
                    valueColor: alertProvider.activeCount > 0 ? redColor : greenColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Per-JVM Real-time Metric Cards with Mini Sparklines
          if (jvms.isNotEmpty) ...[
            _buildSectionHeader('JVM Health Overview', Icons.monitor_heart),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth > 900
                    ? (constraints.maxWidth - 32) / 3
                    : constraints.maxWidth > 600
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: jvms.map((jvm) {
                    return SizedBox(
                      width: cardWidth,
                      child: _buildJvmMetricCard(jvm),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // Active Alerts Section
          if (alertProvider.alerts.isNotEmpty) ...[
            _buildAlertsPanel(alertProvider),
            const SizedBox(height: 24),
          ],

          // JVM Table
          Container(
            decoration: BoxDecoration(
              color: getSurfaceColor(context),
              border: Border.all(color: getBorderColor(context)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'All JVM Processes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: getTextColor(context),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _loadingHistories ? null : _loadAllTrends,
                      icon: _loadingHistories
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: primaryColor),
                            )
                          : const Icon(Icons.refresh, size: 14),
                      label: const Text('Refresh Trends'),
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
                          Text(
                            'Discovering JVM processes...',
                            style: TextStyle(color: getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: TextStyle(
                        color: getTextSecondary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dataTextStyle: TextStyle(
                        color: getTextColor(context),
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
                                    TextStyle(color: getTextSecondary(context)),
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
                                style: TextStyle(
                                    fontSize: 12, color: getTextSecondary(context)),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: getTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildJvmMetricCard(Jvm jvm) {
    final history = _jvmHistories[jvm.pid];
    final statusColor = jvmStatusColor(jvm.status);
    final heapData = history?.snapshots
            .map((s) => s.heapPercent)
            .toList() ??
        [];
    final threadData = history?.snapshots
            .map((s) => s.threadCount.toDouble())
            .toList() ??
        [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border.all(color: getBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and status
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jvm.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: getTextColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'PID ${jvm.pid}',
                      style: TextStyle(fontSize: 11, color: getTextSecondary(context)),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: jvm.status),
            ],
          ),
          const SizedBox(height: 12),

          // Quick stats row
          Row(
            children: [
              _miniMetric('Heap', '${jvm.heapUsagePercent.toStringAsFixed(0)}%',
                  heapBarColor(jvm.heapUsagePercent)),
              const SizedBox(width: 16),
              _miniMetric('Threads', '${jvm.threadCount}', cyanColor),
              const SizedBox(width: 16),
              _miniMetric('CPU', '${jvm.cpuUsagePercent.toStringAsFixed(0)}%', purpleColor),
            ],
          ),
          const SizedBox(height: 12),

          // Mini sparklines
          if (heapData.length >= 2) ...[
            Row(
              children: [
                Expanded(
                  child: _miniSparkline(heapData, 'Heap',
                      heapBarColor(jvm.heapUsagePercent)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniSparkline(threadData, 'Threads', cyanColor),
                ),
              ],
            ),
          ] else
            Text(
              'Collecting metrics...',
              style: TextStyle(
                  color: getTextSecondary(context).withValues(alpha: 0.6),
                  fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _miniSparkline(List<double> data, String label, Color color) {
    return Sparkline(
      data: data,
      lineColor: color,
      label: label,
      height: 35,
    );
  }

  Widget _buildAlertsPanel(AlertProvider alertProvider) {
    final recentAlerts = alertProvider.alerts.take(10).toList();
    return Container(
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border.all(color: getBorderColor(context)),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const Spacer(),
              if (alertProvider.alerts.isNotEmpty)
                TextButton(
                  onPressed: () => alertProvider.clearAlerts(),
                  style: TextButton.styleFrom(
                    foregroundColor: getTextSecondary(context),
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
                    : getTextSecondary(context);
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
                      style: TextStyle(color: getTextColor(context), fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo(alert.timestamp),
                    style: TextStyle(color: getTextSecondary(context), fontSize: 11),
                  ),
                ],
              ),
            );
          }),
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

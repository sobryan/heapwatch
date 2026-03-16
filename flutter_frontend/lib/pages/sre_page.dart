import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jvm.dart';
import '../providers/sre_provider.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/status_badge.dart';

class SrePage extends StatefulWidget {
  const SrePage({super.key});

  @override
  State<SrePage> createState() => _SrePageState();
}

class _SrePageState extends State<SrePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SreProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sre = context.watch<SreProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            children: [
              const Icon(Icons.security, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'SRE Agent',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Agent Status Card
          _buildAgentStatusCard(sre),
          const SizedBox(height: 20),

          // If viewing incident detail
          if (sre.selectedIncident != null) ...[
            _buildIncidentDetail(sre, sre.selectedIncident!),
            const SizedBox(height: 20),
          ],

          // Incidents List
          _buildIncidentsList(sre),
        ],
      ),
    );
  }

  Widget _buildAgentStatusCard(SreProvider sre) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border.all(color: getBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sre.isRunning ? Icons.play_circle : Icons.pause_circle,
                color: sre.isRunning ? greenColor : yellowColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Agent Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => sre.toggleAgent(),
                icon: Icon(
                  sre.isRunning ? Icons.pause : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(sre.isRunning ? 'Pause' : 'Start'),
                style: FilledButton.styleFrom(
                  backgroundColor: sre.isRunning ? yellowColor : greenColor,
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _statusMetric('Status', sre.isRunning ? 'RUNNING' : 'PAUSED',
                  sre.isRunning ? greenColor : yellowColor),
              _statusMetric('Total Scans', '${sre.totalScans}', primaryColor),
              _statusMetric('Anomalies Found', '${sre.anomaliesDetected}',
                  sre.anomaliesDetected > 0 ? redColor : greenColor),
              _statusMetric('Open Incidents', '${sre.openIncidents}',
                  sre.openIncidents > 0 ? redColor : greenColor),
              _statusMetric('Last Scan', timeAgo(sre.lastScanTime),
                  getTextSecondary(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildIncidentsList(SreProvider sre) {
    final incidents = sre.incidents;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border.all(color: getBorderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: yellowColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Incidents (${incidents.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => sre.loadIncidents(),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (incidents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: greenColor, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'No incidents detected',
                      style: TextStyle(
                        color: getTextSecondary(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The SRE Agent is monitoring for anomalies.',
                      style: TextStyle(
                        color: getTextSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...incidents.take(20).map((incident) => _buildIncidentRow(sre, incident)),
        ],
      ),
    );
  }

  Widget _buildIncidentRow(SreProvider sre, SreIncident incident) {
    final severityColor = _severityColor(incident.severity);
    final isOpen = incident.status == 'OPEN';

    return InkWell(
      onTap: () => sre.selectIncident(incident.id),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: severityColor.withValues(alpha: 0.06),
          border: Border(
            left: BorderSide(color: severityColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            StatusBadge(status: incident.severity),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incident.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${incident.anomalyType} - ${incident.affectedJvm ?? incident.processName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: incident.status),
            const SizedBox(width: 8),
            Text(
              timeAgo(incident.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: getTextSecondary(context),
              ),
            ),
            if (isOpen) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => sre.resolveIncident(incident.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                color: greenColor,
                tooltip: 'Resolve',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentDetail(SreProvider sre, SreIncident incident) {
    final severityColor = _severityColor(incident.severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border.all(color: severityColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.report, color: severityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  incident.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => sre.clearSelectedIncident(),
                icon: const Icon(Icons.close, size: 18),
                color: getTextSecondary(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Meta row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              StatusBadge(status: incident.severity),
              StatusBadge(status: incident.status),
              _metaChip(Icons.memory, incident.anomalyType),
              _metaChip(Icons.computer, incident.affectedJvm ?? ''),
            ],
          ),
          const SizedBox(height: 16),

          // Diagnosis
          Text(
            'Diagnosis',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: getBgColor(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              incident.diagnosis ?? incident.description,
              style: TextStyle(fontSize: 13, color: getTextColor(context)),
            ),
          ),
          const SizedBox(height: 16),

          // Recommended Fix
          if (incident.recommendedFix != null) ...[
            Text(
              'Recommended Fix',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: greenColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: greenColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                incident.recommendedFix!,
                style: TextStyle(fontSize: 13, color: getTextColor(context)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timeline
          Text(
            'Timeline',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          ...incident.timeline.map((event) => _buildTimelineEvent(event)),

          // Resolve button
          if (incident.status == 'OPEN') ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sre.loading ? null : () => sre.resolveIncident(incident.id),
              icon: sre.loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle, size: 16),
              label: const Text('Resolve Incident'),
              style: FilledButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(IncidentEvent event) {
    final typeColor = switch (event.type) {
      'DETECTED' => redColor,
      'INVESTIGATING' => yellowColor,
      'DIAGNOSIS_COMPLETE' => primaryColor,
      'RESOLVED' => greenColor,
      _ => getTextSecondary(context),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: typeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo(event.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                Text(
                  event.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: getTextSecondary(context)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: getTextSecondary(context)),
        ),
      ],
    );
  }

  Color _severityColor(String severity) {
    return switch (severity) {
      'CRITICAL' => redColor,
      'HIGH' => const Color(0xFFFF6B6B),
      'MEDIUM' => yellowColor,
      'LOW' => primaryColor,
      _ => getTextSecondary(context),
    };
  }
}

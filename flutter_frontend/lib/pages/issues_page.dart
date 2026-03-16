import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jvm.dart';
import '../providers/issues_provider.dart';
import '../theme.dart';

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<IssuesProvider>();
      provider.loadRepoStatus();
      provider.loadIssues();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IssuesProvider>();
    final selectedIssue = provider.selectedIssue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.bug_report, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Issues',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const Spacer(),
              // Severity summary
              _severityChip('CRITICAL', provider.criticalCount, redColor),
              const SizedBox(width: 6),
              _severityChip('HIGH', provider.highCount, const Color(0xFFFB923C)),
              const SizedBox(width: 6),
              _severityChip('MEDIUM', provider.mediumCount, yellowColor),
              const SizedBox(width: 6),
              _severityChip('LOW', provider.lowCount, primaryColor),
            ],
          ),
          const SizedBox(height: 16),

          // Repo connection status
          _buildRepoStatus(provider),
          const SizedBox(height: 16),

          // Error message
          if (provider.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: redColor.withValues(alpha: 0.1),
                border: Border.all(color: redColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: redColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(provider.error!,
                        style: const TextStyle(color: redColor, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main content: list + detail
          if (selectedIssue != null)
            _buildIssueDetail(provider, selectedIssue)
          else
            _buildIssueList(provider),
        ],
      ),
    );
  }

  Widget _severityChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRepoStatus(IssuesProvider provider) {
    final repo = provider.repoStatus;
    final connected = repo?.connected ?? false;

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
          Row(
            children: [
              Icon(
                connected ? Icons.link : Icons.link_off,
                color: connected ? greenColor : getTextSecondary(context),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Repository',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const Spacer(),
              if (connected) ...[
                Text(
                  '${repo!.indexedFiles} files indexed',
                  style: TextStyle(fontSize: 12, color: getTextSecondary(context)),
                ),
                const SizedBox(width: 12),
              ],
              _buildConnectButton(provider),
            ],
          ),
          if (connected && repo != null) ...[
            const SizedBox(height: 8),
            Text(
              '${repo.repoUrl ?? "Local"} (${repo.branch ?? "main"})',
              style: TextStyle(fontSize: 12, color: getTextSecondary(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectButton(IssuesProvider provider) {
    return OutlinedButton.icon(
      onPressed: provider.connecting ? null : () => _showConnectDialog(provider),
      icon: provider.connecting
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            )
          : const Icon(Icons.cable, size: 14),
      label: Text(provider.repoStatus?.connected == true ? 'Reconnect' : 'Connect Repo'),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  void _showConnectDialog(IssuesProvider provider) {
    final urlController = TextEditingController();
    final branchController = TextEditingController(text: 'main');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Repository'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'GitHub URL or local path',
                  hintText: 'https://github.com/user/repo.git',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: branchController,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  hintText: 'main',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.connectRepo(
                urlController.text.trim(),
                branch: branchController.text.trim(),
              );
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueList(IssuesProvider provider) {
    if (provider.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (provider.issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, color: greenColor, size: 48),
            const SizedBox(height: 16),
            Text(
              'No issues detected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: getTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect a repository and run profiling to identify code issues.',
              style: TextStyle(fontSize: 13, color: getTextSecondary(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: provider.issues.map((issue) => _buildIssueCard(provider, issue)).toList(),
    );
  }

  Widget _buildIssueCard(IssuesProvider provider, CodeIssue issue) {
    final severityColor = _severityColor(issue.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => provider.selectIssue(issue),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: getSurfaceColor(context),
            border: Border.all(color: getBorderColor(context)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Severity indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Issue info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _severityBadge(issue.severity, severityColor),
                        const SizedBox(width: 8),
                        _categoryBadge(issue.category),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: getTextColor(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.description,
                      style: TextStyle(fontSize: 12, color: getTextSecondary(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (issue.method != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        issue.method!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: getTextSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Impact score
              Column(
                children: [
                  Text(
                    '${issue.impactScore}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: severityColor,
                    ),
                  ),
                  Text(
                    '/10',
                    style: TextStyle(fontSize: 10, color: getTextSecondary(context)),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: getTextSecondary(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueDetail(IssuesProvider provider, CodeIssue issue) {
    final severityColor = _severityColor(issue.severity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        TextButton.icon(
          onPressed: () => provider.selectIssue(null),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back to issues'),
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
        const SizedBox(height: 12),

        // Issue header
        Container(
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
                  _severityBadge(issue.severity, severityColor),
                  const SizedBox(width: 8),
                  _categoryBadge(issue.category),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
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
              const SizedBox(height: 12),
              Text(
                issue.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                issue.description,
                style: TextStyle(fontSize: 13, color: getTextSecondary(context)),
              ),
              if (issue.method != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.code, size: 14, color: getTextSecondary(context)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.method!,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: cyanColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (issue.filePath != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.insert_drive_file, size: 14, color: getTextSecondary(context)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${issue.filePath} (lines ${issue.lineStart}-${issue.lineEnd})',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Profiling metrics
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (issue.cpuPercent > 0) _metricChip('CPU', '${issue.cpuPercent.toStringAsFixed(1)}%'),
                  if (issue.allocationBytes > 0) _metricChip('Alloc', _formatBytes(issue.allocationBytes)),
                  if (issue.threadCount > 0) _metricChip('Threads', '${issue.threadCount}'),
                  if (issue.gcPauseMs > 0) _metricChip('GC', '${issue.gcPauseMs}ms'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Source code snippet
        if (issue.sourceSnippet != null && issue.sourceSnippet!.isNotEmpty) ...[
          _buildPanel(
            title: 'Source Code',
            icon: Icons.code,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: getBgColor(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                issue.sourceSnippet!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: getTextColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // AI Analysis section
        _buildPanel(
          title: 'AI Analysis',
          icon: Icons.smart_toy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (issue.analyzed && issue.rootCause != null) ...[
                Text(
                  'Root Cause',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  issue.rootCause!,
                  style: TextStyle(fontSize: 13, color: getTextSecondary(context)),
                ),
                const SizedBox(height: 16),

                // Before/After diff
                if (issue.beforeCode != null && issue.afterCode != null) ...[
                  Text(
                    'Before (problematic)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: redColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: redColor.withValues(alpha: 0.05),
                      border: Border.all(color: redColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      issue.beforeCode!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: redColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'After (fixed)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: greenColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: greenColor.withValues(alpha: 0.05),
                      border: Border.all(color: greenColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      issue.afterCode!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: greenColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (issue.estimatedImpact != null) ...[
                  Text(
                    'Estimated Impact',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.estimatedImpact!,
                    style: TextStyle(fontSize: 13, color: greenColor),
                  ),
                ],
              ] else ...[
                Text(
                  'Run AI analysis to get root cause, code fix, and impact estimate.',
                  style: TextStyle(fontSize: 13, color: getTextSecondary(context)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: provider.analyzingId == issue.id
                        ? null
                        : () => provider.analyzeIssue(issue.id),
                    icon: provider.analyzingId == issue.id
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high, size: 16),
                    label: Text(issue.analyzed ? 'Re-analyze' : 'Generate Fix'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: getBgColor(context),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (issue.analyzed) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: provider.creatingPrId == issue.id
                          ? null
                          : () => provider.createPr(issue.id),
                      icon: provider.creatingPrId == issue.id
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                            )
                          : const Icon(Icons.merge_type, size: 16),
                      label: Text(issue.prCreated ? 'PR Created' : 'Create PR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: issue.prCreated ? greenColor : primaryColor,
                        side: BorderSide(color: issue.prCreated ? greenColor : primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PR Plan (if created)
        if (issue.prCreated && issue.prBranch != null) ...[
          _buildPanel(
            title: 'PR Plan',
            icon: Icons.merge_type,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _prDetailRow('Branch', issue.prBranch!),
                _prDetailRow('Title', issue.prTitle ?? ''),
                if (issue.prDiff != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Diff',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getBgColor(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      issue.prDiff!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: getTextColor(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _prDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: getTextSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _severityBadge(String severity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: getSurface2Color(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: getTextSecondary(context),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: getSurface2Color(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: getTextSecondary(context)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return redColor;
      case 'HIGH':
        return const Color(0xFFFB923C); // orange
      case 'MEDIUM':
        return yellowColor;
      case 'LOW':
        return primaryColor;
      default:
        return textSecondary;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

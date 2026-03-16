import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jvm.dart';
import '../providers/sre_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  final _discoveryIntervalController = TextEditingController();
  final _jfrDurationController = TextEditingController();
  final _heapWarningController = TextEditingController();
  final _heapCriticalController = TextEditingController();
  final _threadWarningController = TextEditingController();
  bool _aiEnabled = true;
  String _aiModel = 'claude-sonnet-4-20250514';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _discoveryIntervalController.dispose();
    _jfrDurationController.dispose();
    _heapWarningController.dispose();
    _heapCriticalController.dispose();
    _threadWarningController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final settings = await api.getSettings();
      setState(() {
        _discoveryIntervalController.text = '${settings['discoveryIntervalSeconds'] ?? 15}';
        _jfrDurationController.text = '${settings['jfrDefaultDurationSeconds'] ?? 30}';
        _heapWarningController.text = '${(settings['heapWarningThreshold'] ?? 85.0).toInt()}';
        _heapCriticalController.text = '${(settings['heapCriticalThreshold'] ?? 95.0).toInt()}';
        _threadWarningController.text = '${settings['threadWarningThreshold'] ?? 500}';
        _aiEnabled = settings['aiEnabled'] ?? true;
        _aiModel = settings['aiModel'] ?? 'claude-sonnet-4-20250514';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final api = context.read<ApiService>();
      final updates = <String, dynamic>{
        'discoveryIntervalSeconds': int.tryParse(_discoveryIntervalController.text) ?? 15,
        'jfrDefaultDurationSeconds': int.tryParse(_jfrDurationController.text) ?? 30,
        'heapWarningThreshold': double.tryParse(_heapWarningController.text) ?? 85.0,
        'heapCriticalThreshold': double.tryParse(_heapCriticalController.text) ?? 95.0,
        'threadWarningThreshold': int.tryParse(_threadWarningController.text) ?? 500,
        'aiEnabled': _aiEnabled,
        'aiModel': _aiModel,
      };
      await api.updateSettings(updates);
      setState(() {
        _successMessage = 'Settings saved successfully.';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Success / Error messages
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: greenColor.withValues(alpha: 0.1),
                border: Border.all(color: greenColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: greenColor, size: 16),
                  const SizedBox(width: 8),
                  Text(_successMessage!, style: const TextStyle(color: greenColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: redColor.withValues(alpha: 0.1),
                border: Border.all(color: redColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: redColor, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],

          // Appearance Section
          _buildSection(
            title: 'Appearance',
            icon: Icons.palette,
            children: [
              Row(
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(fontSize: 13, color: getTextColor(context)),
                  ),
                  const Spacer(),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return Switch(
                        value: themeProvider.isDark,
                        onChanged: (v) => themeProvider.setDark(v),
                        activeTrackColor: primaryColor,
                      );
                    },
                  ),
                ],
              ),
              Text(
                'Toggle between dark and light theme.',
                style: TextStyle(fontSize: 12, color: getTextSecondary(context)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Discovery Section
          _buildSection(
            title: 'Discovery',
            icon: Icons.search,
            children: [
              _buildNumberField(
                label: 'Discovery Interval (seconds)',
                controller: _discoveryIntervalController,
                hint: 'How often to scan for JVM processes (5-300)',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Alert Thresholds Section
          _buildSection(
            title: 'Alert Thresholds',
            icon: Icons.warning_amber,
            children: [
              _buildNumberField(
                label: 'Heap Warning Threshold (%)',
                controller: _heapWarningController,
                hint: 'Heap usage percentage to trigger WARNING alert',
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                label: 'Heap Critical Threshold (%)',
                controller: _heapCriticalController,
                hint: 'Heap usage percentage to trigger CRITICAL alert',
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                label: 'Thread Warning Threshold',
                controller: _threadWarningController,
                hint: 'Thread count to trigger WARNING alert',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // JFR Defaults Section
          _buildSection(
            title: 'JFR Defaults',
            icon: Icons.fiber_manual_record,
            children: [
              _buildNumberField(
                label: 'Default Recording Duration (seconds)',
                controller: _jfrDurationController,
                hint: 'Default duration for JFR recordings (5-600)',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // AI Configuration Section
          _buildSection(
            title: 'AI Configuration',
            icon: Icons.smart_toy,
            children: [
              Row(
                children: [
                  const Text(
                    'AI Advisor Enabled',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                  const Spacer(),
                  Switch(
                    value: _aiEnabled,
                    onChanged: (v) => setState(() => _aiEnabled = v),
                    activeTrackColor: primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'AI Model',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _aiModel,
                dropdownColor: surfaceColor,
                style: const TextStyle(fontSize: 13, color: textColor),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'claude-sonnet-4-20250514', child: Text('Claude Sonnet 4')),
                  DropdownMenuItem(value: 'claude-opus-4-20250514', child: Text('Claude Opus 4')),
                  DropdownMenuItem(value: 'claude-haiku-4-20250514', child: Text('Claude Haiku 4')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _aiModel = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Alert Integrations Section
          _IntegrationsSection(),
          const SizedBox(height: 24),

          // Save button
          FilledButton.icon(
            onPressed: _saving ? null : _saveSettings,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: bgColor),
                  )
                : const Icon(Icons.save, size: 16),
            label: const Text('Save Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: bgColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: textSecondary)),
        const SizedBox(height: 6),
        SizedBox(
          width: 300,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

/// Alert Integrations management section for the Settings page.
class _IntegrationsSection extends StatefulWidget {
  @override
  State<_IntegrationsSection> createState() => _IntegrationsSectionState();
}

class _IntegrationsSectionState extends State<_IntegrationsSection> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SreProvider>().loadIntegrations();
      setState(() => _loaded = true);
    });
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String type = 'WEBHOOK';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Integration', style: TextStyle(fontSize: 16)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    style: TextStyle(fontSize: 13, color: getTextColor(context)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    style: TextStyle(fontSize: 13, color: getTextColor(context)),
                    items: const [
                      DropdownMenuItem(value: 'WEBHOOK', child: Text('Webhook')),
                      DropdownMenuItem(value: 'GITHUB_ISSUES', child: Text('GitHub Issues')),
                      DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: type == 'WEBHOOK'
                          ? 'Webhook URL'
                          : type == 'GITHUB_ISSUES'
                              ? 'Repo (owner/repo)'
                              : 'Email Address',
                    ),
                    style: TextStyle(fontSize: 13, color: getTextColor(context)),
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
                  final config = <String, String>{};
                  if (type == 'WEBHOOK') {
                    config['url'] = urlCtrl.text;
                  } else if (type == 'GITHUB_ISSUES') {
                    config['repo'] = urlCtrl.text;
                    config['token'] = '';
                  } else {
                    config['to'] = urlCtrl.text;
                  }
                  context.read<SreProvider>().addIntegration({
                    'name': nameCtrl.text,
                    'type': type,
                    'config': config,
                    'enabled': true,
                  });
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: bgColor,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sre = context.watch<SreProvider>();
    final integrations = sre.integrations;

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
          Row(
            children: [
              const Icon(Icons.notifications_active, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Alert Integrations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
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
          Text(
            'Configure notification channels for alerts. Escalation: LOW=webhook, MEDIUM=webhook+email, HIGH/CRITICAL=all channels.',
            style: TextStyle(fontSize: 12, color: getTextSecondary(context)),
          ),
          const SizedBox(height: 16),
          if (integrations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No integrations configured. Add a webhook, GitHub, or email channel.',
                style: TextStyle(fontSize: 13, color: getTextSecondary(context)),
              ),
            )
          else
            ...integrations.map((ch) => _buildChannelCard(sre, ch)),
        ],
      ),
    );
  }

  Widget _buildChannelCard(SreProvider sre, AlertIntegrationChannel ch) {
    final typeIcon = switch (ch.type) {
      'WEBHOOK' => Icons.webhook,
      'GITHUB_ISSUES' => Icons.code,
      'EMAIL' => Icons.email,
      _ => Icons.notifications,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(typeIcon, size: 18, color: primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ch.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                Text(
                  '${ch.type} - ${ch.enabled ? "Enabled" : "Disabled"}',
                  style: const TextStyle(fontSize: 11, color: textSecondary),
                ),
                if (ch.lastTestResult != null)
                  Text(
                    'Last test: ${ch.lastTestResult}',
                    style: TextStyle(
                      fontSize: 10,
                      color: ch.lastTestResult == 'SUCCESS' ? greenColor : redColor,
                    ),
                  ),
              ],
            ),
          ),
          // Test button
          IconButton(
            onPressed: () async {
              final result = await sre.testIntegration(ch.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']?.toString() ?? 'Test completed'),
                    backgroundColor: result['success'] == true ? greenColor : redColor,
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, size: 16),
            color: primaryColor,
            tooltip: 'Test',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Delete button
          IconButton(
            onPressed: () => sre.deleteIntegration(ch.id),
            icon: const Icon(Icons.delete_outline, size: 16),
            color: redColor,
            tooltip: 'Delete',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

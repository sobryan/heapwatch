import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme.dart';
import '../utils.dart';

class NotificationPanel extends StatelessWidget {
  final VoidCallback onClose;

  const NotificationPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(
          color: getSurfaceColor(context),
          border: Border.all(color: getBorderColor(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.notifications, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: getTextColor(context),
                    ),
                  ),
                  if (provider.unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () => provider.markAllRead(),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Mark all read'),
                    ),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close, size: 18, color: getTextSecondary(context)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: getBorderColor(context)),

            // Notification list
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none, size: 36, color: getTextSecondary(context)),
                    const SizedBox(height: 8),
                    Text(
                      'No notifications',
                      style: TextStyle(color: getTextSecondary(context), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: notifications.length > 20 ? 20 : notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final severityColor = n.severity == 'CRITICAL'
                        ? redColor
                        : n.severity == 'WARNING'
                            ? yellowColor
                            : primaryColor;
                    final typeIcon = switch (n.type) {
                      'ALERT' => Icons.warning_amber,
                      'RECORDING' => Icons.fiber_manual_record,
                      'DIAGNOSIS' => Icons.health_and_safety,
                      'HEAP_DUMP' => Icons.memory,
                      _ => Icons.info_outline,
                    };

                    return Container(
                      decoration: BoxDecoration(
                        color: n.read
                            ? Colors.transparent
                            : severityColor.withValues(alpha: 0.04),
                        border: Border(
                          bottom: BorderSide(color: getBorderColor(context).withValues(alpha: 0.5)),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: Icon(typeIcon, size: 18, color: severityColor),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                            color: getTextColor(context),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.message,
                              style: TextStyle(fontSize: 11, color: getTextSecondary(context)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              timeAgo(n.timestamp),
                              style: TextStyle(fontSize: 10, color: getTextSecondary(context)),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          onPressed: () => provider.deleteNotification(n.id),
                          icon: Icon(Icons.close, size: 14, color: getTextSecondary(context)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

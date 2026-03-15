import 'package:flutter/material.dart';
import '../models/jvm.dart';
import '../theme.dart';
import 'status_badge.dart';
import 'heap_bar.dart';

class JvmSidebarCard extends StatelessWidget {
  final Jvm jvm;
  final bool selected;
  final VoidCallback onTap;

  const JvmSidebarCard({
    super.key,
    required this.jvm,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusCol = jvmStatusColor(jvm.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.05) : bgColor,
          border: Border.all(
            color: selected ? primaryColor : borderColor,
          ),
          borderRadius: BorderRadius.circular(8),
          // Left border accent for status
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: statusCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jvm.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PID ${jvm.pid} · ${jvm.hostName ?? 'local'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusBadge(status: jvm.status),
                Text(
                  '${jvm.threadCount} threads',
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
            HeapBar(used: jvm.heapUsedBytes, max: jvm.heapMaxBytes),
          ],
        ),
      ),
    );
  }
}

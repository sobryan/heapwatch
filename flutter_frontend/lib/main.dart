import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/jvm_provider.dart';
import 'providers/profiler_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'pages/dashboard_page.dart';
import 'pages/profiler_page.dart';
import 'pages/chat_page.dart';
import 'pages/settings_page.dart';
import 'widgets/jvm_sidebar_card.dart';
import 'widgets/notification_panel.dart';
import 'theme.dart';

void main() {
  runApp(const HeapWatchApp());
}

class HeapWatchApp extends StatelessWidget {
  const HeapWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => JvmProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ProfilerProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ChatProvider(apiService)),
        ChangeNotifierProvider(create: (_) => AlertProvider(apiService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'HeapWatch \u2014 JVM Performance Monitor',
            theme: themeProvider.isDark ? appTheme : lightAppTheme,
            debugShowCheckedModeBanner: false,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;
  bool _showNotifications = false;

  void _switchTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  void _selectJvmAndProfile(dynamic jvm) {
    context.read<JvmProvider>().selectJvm(jvm);
    setState(() {
      _tabIndex = 1; // Switch to profiler
    });
  }

  void _toggleNotifications() {
    setState(() {
      _showNotifications = !_showNotifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    final jvmProvider = context.watch<JvmProvider>();
    final alertProvider = context.watch<AlertProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 768;
    final isNarrow = screenWidth < 600;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top Nav Bar
              _buildNavBar(jvmProvider, alertProvider, notifProvider, isNarrow),

              // Main content area
              Expanded(
                child: isWide
                    ? Row(
                        children: [
                          // Sidebar
                          _buildSidebar(jvmProvider),
                          // Content
                          Expanded(child: _buildContent()),
                        ],
                      )
                    : Column(
                        children: [
                          // Collapsed sidebar on mobile
                          _buildMobileSidebar(jvmProvider),
                          // Content
                          Expanded(child: _buildContent()),
                        ],
                      ),
              ),
            ],
          ),

          // Notification panel overlay
          if (_showNotifications)
            Positioned(
              top: 56,
              right: 16,
              child: NotificationPanel(
                onClose: () => setState(() => _showNotifications = false),
              ),
            ),
        ],
      ),
      // Bottom nav for narrow/portrait screens
      bottomNavigationBar: isNarrow
          ? BottomNavigationBar(
              currentIndex: _tabIndex,
              onTap: _switchTab,
              backgroundColor: getSurfaceColor(context),
              selectedItemColor: primaryColor,
              unselectedItemColor: getTextSecondary(context),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Profiler',
                ),
                BottomNavigationBarItem(
                  icon: _buildAlertBadgeIcon(
                      Icons.smart_toy, alertProvider.activeCount, isBottom: true),
                  label: 'AI Advisor',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildNavBar(JvmProvider jvmProvider, AlertProvider alertProvider,
      NotificationProvider notifProvider, bool isNarrow) {
    final statusDotColor = jvmProvider.overallStatus == 'red'
        ? redColor
        : jvmProvider.overallStatus == 'yellow'
            ? yellowColor
            : greenColor;

    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 24),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border(bottom: BorderSide(color: getBorderColor(context))),
      ),
      child: Row(
        children: [
          // Brand
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monitor_heart, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                'HeapWatch',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ],
          ),

          // Tab buttons - hidden on narrow screens (use bottom nav instead)
          if (!isNarrow) ...[
            const SizedBox(width: 32),
            _tabButton('Dashboard', 0),
            _tabButton('Profiler', 1),
            _tabButton('AI Advisor', 2),
            _tabButton('Settings', 3),
          ],

          const Spacer(),

          // Notification bell
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: _toggleNotifications,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: _buildAlertBadgeIcon(
                  Icons.notifications_outlined,
                  notifProvider.unreadCount,
                ),
              ),
            ),
          ),

          // Alert indicator
          if (alertProvider.activeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: () => _switchTab(0), // Go to dashboard to see alerts
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: redColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: redColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, color: redColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${alertProvider.activeCount}',
                        style: const TextStyle(
                          color: redColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Status indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusDotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isNarrow
                    ? '${jvmProvider.jvms.length} JVMs'
                    : '${jvmProvider.jvms.length} JVMs monitored',
                style: TextStyle(
                  fontSize: 13,
                  color: getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBadgeIcon(IconData icon, int count, {bool isBottom = false}) {
    if (count == 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: redColor,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tabIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: () => _switchTab(index),
        style: TextButton.styleFrom(
          backgroundColor:
              active ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          foregroundColor: active ? primaryColor : getTextSecondary(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildSidebar(JvmProvider jvmProvider) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border(right: BorderSide(color: getBorderColor(context))),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JVM Processes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: getTextSecondary(context),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => jvmProvider.refreshJvms(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Icon(Icons.refresh, size: 14),
                ),
              ],
            ),
          ),

          // JVM list
          Expanded(
            child: jvmProvider.jvms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                          'Scanning for JVMs...',
                          style:
                              TextStyle(fontSize: 13, color: getTextSecondary(context)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: jvmProvider.jvms.length,
                    itemBuilder: (context, index) {
                      final jvm = jvmProvider.jvms[index];
                      return JvmSidebarCard(
                        jvm: jvm,
                        selected:
                            jvmProvider.selectedJvm?.pid == jvm.pid,
                        onTap: () => _selectJvmAndProfile(jvm),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSidebar(JvmProvider jvmProvider) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border(bottom: BorderSide(color: getBorderColor(context))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JVM Processes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: getTextSecondary(context),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => jvmProvider.refreshJvms(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  child: const Icon(Icons.refresh, size: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: jvmProvider.jvms.length,
              itemBuilder: (context, index) {
                final jvm = jvmProvider.jvms[index];
                return SizedBox(
                  width: 220,
                  child: JvmSidebarCard(
                    jvm: jvm,
                    selected: jvmProvider.selectedJvm?.pid == jvm.pid,
                    onTap: () => _selectJvmAndProfile(jvm),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_tabIndex) {
      case 0:
        return DashboardPage(onTabSwitch: _switchTab);
      case 1:
        return const ProfilerPage();
      case 2:
        return const ChatPage();
      case 3:
        return const SettingsPage();
      default:
        return DashboardPage(onTabSwitch: _switchTab);
    }
  }
}

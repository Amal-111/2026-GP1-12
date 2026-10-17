import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../list/palm_list.dart';
import '../map/palm_map.dart';
import '../list/palm_details.dart';
import 'alerts.dart';
import 'alert_details.dart';
import '../theme/glass_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }

}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    MockData.changes.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MockData.changes.removeListener(_refresh);
    super.dispose();
  }

  int selectedTab = 0;
  PalmStatus? selectedPalmFilter;

  // for farmer assigned farm only and for farmOwner selected farm
  String get activeFarmId {
    if (MockData.currentUser.role == UserRole.farmer) {
      return MockData.currentUser.farmId ?? '';
    }
    return MockData.selectedFarmId;
  }

  bool get hasFarmAccess {
    return MockData.farms.any((farm) => farm.id == activeFarmId);
  }

  String get activeFarmName {
    for (final farm in MockData.farms) {
      if (farm.id == activeFarmId) {
        return farm.name;
      }
    }
    return 'No assigned farm';
  }

  List<PalmData> get farmPalms {
    if (!hasFarmAccess) {
      return [];
    }
    return MockData.palmsForFarm(activeFarmId);
  }

  List<AlertData> get recentFarmAlerts {
    if (!hasFarmAccess) {
      return [];
    }

    final result = MockData.alerts.where((alert) {
      return alert.farmId == activeFarmId && alert.isCurrent;
    }).toList();

    result.sort((first, second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return result.take(3).toList();
  }

  List<PalmData> get offlineFarmPalms {
    return farmPalms.where((palm) {
      return !palm.deviceOnline;
    }).toList();
  }

  int countStatus(PalmStatus status) {
    return farmPalms.where((palm) {
      return palm.status == status;
    }).length;
  }

// palm page
  void openPalms(PalmStatus? status) {
    MockData.selectedFarmId = activeFarmId;
    setState(() {
      selectedPalmFilter = status;
      selectedTab = 1;
    });
  }
// alert page
  void openAlerts() {
    MockData.selectedFarmId = activeFarmId;
    setState(() {
      selectedTab = 3;
    });
  }

  void selectTab(int index) {
    MockData.selectedFarmId = activeFarmId;
    setState(() {
      selectedTab = index;
      if (index == 1) {
        selectedPalmFilter = null;
      }
    });
  }

  String fullDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;

    if (!hasFarmAccess) {
      currentPage = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No farm is assigned to this account.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (selectedTab == 0) {
      currentPage = _homePage();
    } else if (selectedTab == 1) {
      currentPage = PalmListPage(
        key: ValueKey('${activeFarmId}_${selectedPalmFilter?.name}'),
        initialStatus: selectedPalmFilter,
        farmId: activeFarmId,
      );
    } else if (selectedTab == 3) {
      currentPage = AlertsScreen(key: ValueKey(activeFarmId));
    } else if (selectedTab == 2) {
      currentPage = FarmMapPage(key: ValueKey(activeFarmId), farmId: activeFarmId);
    } else {
      currentPage = _ProfilPage('Profile', Icons.person_outline);
    }

    return Scaffold(
      body: currentPage,
      bottomNavigationBar: NavigationBar(
        height: 78,
        selectedIndex: selectedTab,
        onDestinationSelected: selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: PalmIcon(),
            selectedIcon: PalmIcon(),
            label: 'Palms',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _ProfilPage(String title, IconData icon) {
    return SafeArea(
      child: Center(
        child: GlassBox(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 75, color: AppColors.secondary),
            const SizedBox(height: 14),
            Text(
              '$title --',
              style: const TextStyle(fontSize: 20, color: AppColors.primary),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _homePage() {
    final palms = farmPalms;
    final offlinePalms = offlineFarmPalms;
    final recentAlerts = recentFarmAlerts;

    return Stack(
      children: [
        // The palm background now comes from the app theme
        // (same for every page).

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting and farm name
                GlassBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(
                  children: [
                    if (MockData.currentUser.role == UserRole.farmOwner) ...[
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else if (selectedTab != 0) {
                            selectTab(0);
                          }
                        },
                      ),
                    ],
                    Expanded(
                      child: Text(
                        'Hello, ${MockData.currentUser.name}!',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: Colors.white.withValues(alpha: 0.6),
                      child: IconButton(
                        icon: const Icon(Icons.person, color: AppColors.primary),
                        onPressed: () => selectTab(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome back to RASD.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),

                // Farm name
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.brown),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        activeFarmName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                 ],
                ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                GlassBox(
                  padding: const EdgeInsets.all(18),
                  radius: 18,
                  tint: const Color(0xFFE8F3EA),
                  child: Row(
                    children: [
                      const PalmIcon(size: 40, color: AppColors.primary),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Total Palms',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        '${palms.length}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Status cards for Healthy and Suspected
                Row(
                  children: [
                    Expanded(
                      child: _statusCard(
                        PalmStatus.healthy,
                        Icons.park,
                        AppColors.healthy,
                        const Color(0xFFE8F7EE),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statusCard(
                        PalmStatus.suspected,
                        Icons.warning_rounded,
                        AppColors.suspected,
                        const Color(0xFFFDECEC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Under Monitoring and Offline Sensors
                Row(
                  children: [
                    Expanded(
                      child: _statusCard(
                        PalmStatus.underMonitoring,
                        Icons.access_time_filled,
                        AppColors.monitoring,
                        const Color(0xFFFFF4DF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassBox(
                        padding: EdgeInsets.zero,
                        radius: 20,
                        tint: const Color(0xFFF0F2F3),
                        child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _showOfflineSensors,
                          child: Container(
                            height: 145,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: AppColors.offline,
                                  size: 38,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${offlinePalms.length}',
                                        style: const TextStyle(
                                          fontSize: 33,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.offline,
                                        ),
                                      ),
                                      const Text(
                                        'Offline Sensors',
                                        maxLines: 2,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GlassLabel(child: Text(
                  palms.isEmpty
                      ? 'Last updated: No readings available'
                      : 'Last updated: ${fullDateTime(_latestUpdate(palms))}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )),
                const SizedBox(height: 20),

                GlassBox(padding: const EdgeInsets.fromLTRB(14, 4, 4, 4), child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent Alerts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: openAlerts,
                      child: const Text('View All ›'),
                    ),
                  ],
                )),
                if (recentAlerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: GlassLabel(child: Text(
                        'No recent alerts.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      )),
                    ),
                  )
                else
                  ...recentAlerts.map((alert) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _alertCard(alert),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DateTime _latestUpdate(List<PalmData> palms) {
    DateTime latest = palms.first.updatedAt;
    for (final palm in palms) {
      if (palm.updatedAt.isAfter(latest)) {
        latest = palm.updatedAt;
      }
    }
    return latest;
  }

  Widget _statusCard(
      PalmStatus status,
      IconData icon,
      Color color,
      Color background,
      ) {
    return GlassBox(
      padding: EdgeInsets.zero,
      radius: 20,
      tint: background,
      child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          openPalms(status);
        },
        child: Container(
          height: 145,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              appIcon(icon, size: 38, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${countStatus(status)}',
                      style: TextStyle(
                        fontSize: 33,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      palmStatusLabel(status),
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _alertCard(AlertData alert) {
    final color = alertTypeColor(alert.type);
    final palm = MockData.palmById(alert.palmId);
    final palmName = alert.palmId;

    return GlassBox(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return AlertDetailsScreen(alert: alert);
              },
            ),
          );
          if (mounted) {
            setState(() {});
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  alertTypeIcon(alert.type),
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palmName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      alert.title,
                      style: TextStyle(color: color, fontSize: 13),
                    ),
                    Text(
                      fullDateTime(alert.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showOfflineSensors() {
    final offlinePalms = offlineFarmPalms;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline Sensors',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (offlinePalms.isEmpty)
                  const Text('All monitoring devices are online.'),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final palm in offlinePalms)
                        GlassCard(
                          child: ListTile(
                            leading: const Icon(
                              Icons.wifi_off,
                              color: AppColors.offline,
                            ),
                            title: Text('${palm.deviceId} • ${palm.id}'),
                            subtitle: Text(
                              'Palm ID: ${palm.id}\n'
                                  'Location: ${palm.location}\n'
                                  'Last seen: ${fullDateTime(palm.lastSeen)}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return PalmDetailsPage(palmId: palm.id);
                                  },
                                ),
                              ).then((_) {
                                if (mounted) {
                                  setState(() {});
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

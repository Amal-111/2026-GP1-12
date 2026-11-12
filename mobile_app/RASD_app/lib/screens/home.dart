// Home screen: farm summary, palm status counts, recent alerts and bottom navigation.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'alert_details.dart';
import '../services/rasd_alert_service.dart';
import '../data/mock_data.dart' show PalmStatus;
import '../theme/palm_icon.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../list/palm_list.dart';
import '../list/palm_details.dart';
import '../map/palm_map.dart';
import '../profile/profile_page.dart';
import '../services/selected_farm_service.dart';

import 'alerts.dart';
import '../farm_assignment/no_farm_assigned.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';
/// Home page.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Index of the selected bottom tab.
  int selectedTab = 0;
  PalmStatus? selectedPalmFilter;

  String _farmId = '';
  String _farmName = '';
  String _userName = '';
  bool _isOwner = false;

  List<Map<String, dynamic>> _palms = [];
  List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic> _devices = {};

  /// Live stream of the user's record.
  Stream<DatabaseEvent> _watchUser(String uid) {
    return _db.ref('users/$uid').onValue;
  }

  /// Safely converts a database value into a map.
  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) return {};
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! Map) return [];

    return value.entries.map((entry) {
      final data = _asMap(entry.value);
      return <String, dynamic>{
        'id': entry.key.toString(),
        ...data,
      };
    }).toList();
  }

  /// Safely reads a text value.
  String _text(Object? value, [String fallback = '']) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  /// Safely reads a date value.
  DateTime? _date(Object? value) {
    if (value is num) {
      final milliseconds =
      value < 100000000000 ? value.toInt() * 1000 : value.toInt();

      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  /// Formats a date as day/month/year.
  String _formatDate(DateTime date) {
    date = date.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year}  $hour:$minute';
  }

  /// True when the palm's sensor has not reported recently.
  bool _isOffline(Map<String, dynamic> palm) {
    final deviceId = _text(palm['deviceId']);

    if (deviceId.isEmpty) return false;

    final device = _asMap(_devices[deviceId]);

    if (device.isEmpty) return false;

    return _text(device['connectionStatus']).toLowerCase() ==
        'offline';
  }

  /// Reads the palm status as an enum.
  PalmStatus? _status(Map<String, dynamic> palm) {
    switch (_text(palm['healthStatus']).toLowerCase()) {
      case 'suspected':
        return PalmStatus.suspected;
      case 'undermonitoring':
      case 'under_monitoring':
        return PalmStatus.underMonitoring;
      case 'healthy':
        return PalmStatus.healthy;
      default:
        return null;
    }
  }

  /// Counts palms with the given status.
  int _countStatus(PalmStatus status) {
    return _palms.where((palm) => _status(palm) == status).length;
  }

  /// Switches the bottom navigation tab.
  void _selectTab(int index) {
    setState(() {
      selectedTab = index;
      if (index == 1) {
        selectedPalmFilter = null;
      }
    });
  }

  /// Opens the palm list filtered by status.
  void _openPalms(PalmStatus? status) {
    setState(() {
      selectedPalmFilter = status;
      selectedTab = 1;
    });
  }

  /// Opens the alerts screen.
  void _openAlerts() {
    setState(() => selectedTab = 3);
  }

  /// Opens the details of an alert.
  void _openAlertDetails(Map<String, dynamic> alert) {
    final rasdAlert = RasdAlert.fromMap(
      _text(alert['id']),
      _farmId,
      alert,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetailsScreen(alert: rasdAlert),
      ),
    );
  }

  /// Builds the page with localized labels.
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Text(AuthStore.arabic.value
              ? 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.'
              : 'Your session has ended. Please log in again.'),
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _watchUser(uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return _errorPage(userSnapshot.error);
        }

        if (!userSnapshot.hasData) {
          return _loadingPage();
        }

        final user = _asMap(userSnapshot.data!.snapshot.value);

        if (user.isEmpty) {
          return _errorPage(
            AuthStore.arabic.value
                ? 'لم نتمكن من العثور على ملفك الشخصي. سجّل الخروج ثم سجّل الدخول مرة أخرى.'
                : 'We could not find your profile. Log out and log in again.',
          );
        }

        final role = _text(user['role']);
        final isFarmer = role == 'Farmer';
        final isOwner = role == 'FarmOwner';

        if (!isFarmer && !isOwner) {
          return _errorPage(
            AuthStore.arabic.value
                ? 'نوع الحساب هذا غير مدعوم.'
                : 'This account type is not supported.',
          );
        }

        _isOwner = isOwner;
        _userName = _text(user['fullName'], AuthStore.arabic.value ? 'مستخدم' : 'User');

        if (isFarmer) {
          final assignedFarmId = _text(user['farmId']);

          if (assignedFarmId.isEmpty) {
            return const NoFarmAssigned();
          }

          return _buildFarm(
            assignedFarmId,
            farmerId: uid,
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: SelectedFarmService.selectedFarmId,
          builder: (context, selectedFarmId, _) {
            final farmId = selectedFarmId ?? '';

            if (farmId.isEmpty) {
              return  Scaffold(
                body: Center(
                  child: Text(
                    AuthStore.arabic.value
                        ? 'يرجى اختيار مزرعة أولاً.'
                        : 'Choose a farm first.',
                  ),
                ),
              );
            }

            return _buildFarm(farmId, ownerId: uid);
          },
        );
      },
    );
  }

  /// Builds the screen for the current farm data.
  Widget _buildFarm(
      String farmId, {
        String? ownerId,
        String? farmerId,
      }) {
    return StreamBuilder<DatabaseEvent>(
      key: ValueKey('farm_$farmId'),
      stream: _db.ref('farms/$farmId').onValue,
      builder: (context, farmSnapshot) {
        if (farmSnapshot.hasError) {
          return _errorPage(farmSnapshot.error);
        }

        if (!farmSnapshot.hasData) {
          return _loadingPage();
        }

        final farm = _asMap(farmSnapshot.data!.snapshot.value);

        if (farm.isEmpty || farm['deleting'] == true) {
          return _errorPage(
            AuthStore.arabic.value
                ? 'هذه المزرعة غير متاحة حاليًا.'
                : 'This farm is not available right now.',
          );
        }

        if (ownerId != null && farm['ownerId'] != ownerId) {
          return _errorPage(
            AuthStore.arabic.value
                ? 'هذه المزرعة تتبع مالكًا آخر.'
                : 'This farm belongs to another owner.',
          );
        }

        _farmId = farmId;
        _farmName = _text(farm['farmName'], AuthStore.arabic.value ? 'مزرعتي' : 'My Farm');

        return StreamBuilder<DatabaseEvent>(
          key: ValueKey('palms_$farmId'),
          stream: _db.ref('palms/$farmId').onValue,
          builder: (context, palmsSnapshot) {
            if (palmsSnapshot.hasError) {
              return _errorPage(palmsSnapshot.error);
            }

            if (!palmsSnapshot.hasData) {
              return _loadingPage();
            }

            _palms = _asList(palmsSnapshot.data!.snapshot.value);

            return StreamBuilder<DatabaseEvent>(
              key: ValueKey('alerts_$farmId'),
              stream: _db.ref('alerts/$farmId').onValue,
              builder: (context, alertsSnapshot) {
                if (alertsSnapshot.hasError) {
                  return _errorPage(alertsSnapshot.error);
                }

                if (!alertsSnapshot.hasData) {
                  return _loadingPage();
                }

                _alerts = _asList(alertsSnapshot.data!.snapshot.value);

                return StreamBuilder<DatabaseEvent>(
                  key: ValueKey('devices_$farmId'),
                  stream: _db.ref('monitoringDevices').onValue,
                  builder: (context, devicesSnapshot) {
                    if (devicesSnapshot.hasError) {
                      // The home can still show farm data even if
                      // device status is temporarily unavailable.
                      _devices = {};
                    } else if (devicesSnapshot.hasData) {
                      _devices = _asMap(
                        devicesSnapshot.data!.snapshot.value,
                      );
                    }

                    return _buildMainScaffold();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Builds the scaffold with bottom navigation.
  Widget _buildMainScaffold() {
    Widget currentPage;

    switch (selectedTab) {
      case 0:
        currentPage = _homePage();
        break;


      case 1:
        currentPage = PalmListPage(
          key: ValueKey(
            '${_farmId}_${selectedPalmFilter?.name}',
          ),
          farmId: _farmId,
          initialStatus: selectedPalmFilter?.name,
        );
        break;

      case 2:
        currentPage = FarmMapPage(
          key: ValueKey(_farmId),
          farmId: _farmId,
        );
        break;

      case 3:
        currentPage = AlertsScreen(
          key: ValueKey(_farmId),
          farmId: _farmId,
        );
        break;

      default:
        currentPage = const ProfilePage(
          showBackButton: false,
        );
    }

return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return Scaffold(
      body: currentPage,
      bottomNavigationBar: NavigationBar(
        height: 78,
        selectedIndex: selectedTab,
        onDestinationSelected: _selectTab,
        destinations:  [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: isArabic ? 'الرئيسية' : 'Home',
          ),
          NavigationDestination(
            icon: PalmIcon(),
            selectedIcon: PalmIcon(),
            label: isArabic ? 'النخيل' : 'Palms',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: isArabic ? 'الخريطة' : 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: isArabic ? 'التنبيهات' : 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: isArabic ? 'الملف الشخصي' : 'Profile',
          ),
        ],
      ),
);
},
);
  }

  /// Builds the Home tab content.
  Widget _homePage() {
    final isArabic = AuthStore.arabic.value;
    final offlinePalms =
    _palms.where((palm) => _isOffline(palm)).toList();

    final recentAlerts = [..._alerts];

    recentAlerts.sort((a, b) {
      final first = _date(a['timestamp']) ??
          _date(a['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final second = _date(b['timestamp']) ??
          _date(b['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return second.compareTo(first);
    });

    final latestPalmUpdate = _palms
        .map((palm) {
      final deviceId = _text(palm['deviceId']);
      final device = _asMap(_devices[deviceId]);
      return _date(device['lastSeen']);
    })
        .whereType<DateTime>()
        .fold<DateTime?>(
      null,
          (latest, date) =>
      latest == null || date.isAfter(latest)
          ? date
          : latest,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isOwner)
                        IconButton(
                          tooltip: isArabic ? 'رجوع' : 'Back',
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                          ),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      Expanded(
                        child: Text(
                          isArabic ? 'مرحبًا، $_userName!' : 'Hello, $_userName!',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 23,
                        backgroundColor:
                        Colors.white.withValues(alpha: 0.6),
                        child: IconButton(
                          icon: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _selectTab(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic ? 'أهلًا بعودتك إلى رصد.' : 'Welcome back to RASD.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.brown,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _farmName,
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
                  const PalmIcon(
                    size: 40,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isArabic ? 'إجمالي النخيل' : 'Total Palms',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${_palms.length}',
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

            Row(
              children: [
                Expanded(
                  child: _statusCard(
                    PalmStatus.healthy,
                    Icons.park,
                    AppColors.healthy,
                    const Color(0xFFE8F7EE),
                    isArabic ? 'سليم' : 'Healthy',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statusCard(
                    PalmStatus.suspected,
                    Icons.warning_rounded,
                    AppColors.suspected,
                    const Color(0xFFFDECEC),
                    isArabic ? 'مشتبه بالإصابة' : 'Suspected',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _statusCard(
                    PalmStatus.underMonitoring,
                    Icons.access_time_filled,
                    AppColors.monitoring,
                    const Color(0xFFFFF4DF),
                    isArabic ? 'تحت المراقبة' : 'Under Monitoring',
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
                        onTap: () =>
                            _showOfflineSensors(offlinePalms),
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
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${offlinePalms.length}',
                                      style: const TextStyle(
                                        fontSize: 33,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.offline,
                                      ),
                                    ),
                                    Text(
                                      isArabic ? 'حساسات غير متصلة' : 'Offline Sensors',
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

            GlassLabel(
              child: Text(
                latestPalmUpdate == null
                    ? (isArabic
                    ? 'آخر تحديث: لا توجد قراءات'
                    : 'Last updated: No readings available')
                    : (isArabic
                    ? 'آخر تحديث: ${_formatDate(latestPalmUpdate)}'
                    : 'Last updated: ${_formatDate(latestPalmUpdate)}'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 20),

            GlassBox(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isArabic ? 'أحدث التنبيهات' : 'Recent Alerts',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openAlerts,
                    child: Text(isArabic ? 'عرض الكل ›' : 'View All ›'),
                  ),
                ],
              ),
            ),

            if (recentAlerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: GlassLabel(
                    child: Text(
                      isArabic ? 'لا توجد تنبيهات حديثة.' : 'No recent alerts.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...recentAlerts.take(3).map(
                    (alert) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _alertCard(alert),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds one palm-status summary card.
  Widget _statusCard(
      PalmStatus status,
      IconData icon,
      Color color,
      Color background,
      String label,
      ) {
    return GlassBox(
      padding: EdgeInsets.zero,
      radius: 20,
      tint: background,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPalms(status),
          child: Container(
            height: 145,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                appIcon(icon, size: 38, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_countStatus(status)}',
                        style: TextStyle(
                          fontSize: 33,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        label,
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

  /// Builds one alert card.
  Widget _alertCard(Map<String, dynamic> alert) {
    final alertType = _text(alert['alertType']);
    final isArabic = AuthStore.arabic.value;

    final title = alertType == 'SensorOffline'
        ? (isArabic ? 'الحساس غير متصل' : 'Sensor Offline')
        : alertType == 'PossiblePestDetected'
        ? (isArabic ? 'اشتباه بإصابة' : 'Potential Infestation')
        : (isArabic ? 'تنبيه المزرعة' : 'Farm Alert');

    final palmId = _text(alert['palmId']);

    final createdAt =
        _date(alert['timestamp']) ??
            _date(alert['createdAt']);

    return GlassBox(
      padding: EdgeInsets.zero,
      radius: 18,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openAlertDetails(alert),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.suspected
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.suspected,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        palmId.isEmpty ? (isArabic ? 'المزرعة' : 'Farm') : palmId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.suspected,
                          fontSize: 13,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
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

  /// Shows the list of offline sensors.
  void _showOfflineSensors(
      List<Map<String, dynamic>> offlinePalms,
      ) {
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
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                 Text(
                  AuthStore.arabic.value
                      ? 'الحساسات غير المتصلة'
                      : 'Offline Sensors',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (offlinePalms.isEmpty)
                   Text(
                    AuthStore.arabic.value
                        ? 'لم يتم اكتشاف حساسات غير متصلة.'
                        : 'No offline sensors detected.',
                  ),
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
                            title: Text(
                              '${_text(palm['deviceId'])} • ${_text(palm['id'])}',
                            ),
                            subtitle: Text(
                              '${AuthStore.arabic.value ? 'معرّف النخلة' : 'Palm ID'}: ${_text(palm['id'])}',
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PalmDetailsPage(
                                    farmId: _text(palm['farmId']),
                                    palmId: _text(palm['id']),
                                  ),
                                 ),
                              );
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

  /// Full-screen loading indicator.
  Widget _loadingPage() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Full-screen friendly error page.
  Widget _errorPage(Object? error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          // Our own text is shown as it is; any other error becomes a clear message.
          child: Text(
            error == null
                ? RasdErrors.generic
                : (error is String ? error : RasdErrors.message(error)),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

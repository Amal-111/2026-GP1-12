import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

/// Shared map settings so every map in the app looks the same.
class RasdMap {
  /// Where maps open when there is nothing to show (sample farm, Riyadh).
  /// TODO: use the farm's real location from the database.
  static const LatLng farmCenter = LatLng(24.7136, 46.6753);

  /// Map tiles from the internet: satellite photo or street map.
  static TileLayer tiles({required bool satellite}) => TileLayer(
        urlTemplate: satellite
            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'rasd.com.rasd_app',
        maxNativeZoom: 19,
      );

  /// Required credit for the map tiles.
  static Widget attribution({required bool satellite}) => RichAttributionWidget(
        attributions: [
          TextSourceAttribution(
            satellite ? 'Tiles © Esri' : '© OpenStreetMap contributors',
          ),
        ],
      );

  /// Reads a location saved as text, e.g. "24.7136, 46.6753".
  static LatLng? parse(String text) {
    final parts = text.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}

/// Round white button used on top of the maps.
class MapRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const MapRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Glass circle, more solid on hover / press like the other buttons.
    return GlassBox(
      padding: EdgeInsets.zero,
      radius: 21,
      child: Material(
      type: MaterialType.transparency,
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
      ),
      ),
    );
  }
}

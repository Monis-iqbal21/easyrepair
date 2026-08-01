import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _kDark = Color(0xFF1A1A1A);

/// One reusable in-app full-screen map, shared by the client booking-detail
/// and worker-tracking views.
///
/// Deliberately in-app: it never launches an external maps application, so
/// the user stays in HandyGo and a normal back returns to the exact page they
/// came from.
///
/// [markersListenable] lets the caller keep pushing live marker updates (e.g.
/// the Ustaad's moving position) while this page is open, without rebuilding
/// or recreating the map controller.
class FullScreenMapPage extends StatefulWidget {
  final String title;

  /// Live marker source. The map re-renders whenever this notifies.
  final ValueListenable<Set<Marker>> markersListenable;

  /// Where to point the camera initially.
  final LatLng initialTarget;
  final double initialZoom;

  /// Optional bounds to fit once the map is ready — typically job + worker.
  final LatLngBounds? initialBounds;

  const FullScreenMapPage({
    super.key,
    required this.title,
    required this.markersListenable,
    required this.initialTarget,
    this.initialZoom = 14,
    this.initialBounds,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _fitBounds() async {
    final bounds = widget.initialBounds;
    final ctrl = _controller;
    if (bounds == null || ctrl == null) return;
    // A frame is needed before the map can measure itself for a bounds fit.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _kDark,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ValueListenableBuilder<Set<Marker>>(
        valueListenable: widget.markersListenable,
        builder: (context, markers, _) {
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialTarget,
              zoom: widget.initialZoom,
            ),
            markers: markers,
            onMapCreated: (c) {
              _controller = c;
              _fitBounds();
            },
            // Full gesture support — this is the "expanded" experience.
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
          );
        },
      ),
    );
  }
}

/// Bottom-right expand affordance for an inline map preview.
///
/// Positioned bottom-right by the caller so it cannot cover Google's
/// attribution (bottom-left) or the zoom controls (which inline previews
/// disable anyway).
class MapExpandButton extends StatelessWidget {
  final VoidCallback onTap;

  const MapExpandButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.fullscreen_rounded, size: 20, color: _kDark),
        ),
      ),
    );
  }
}

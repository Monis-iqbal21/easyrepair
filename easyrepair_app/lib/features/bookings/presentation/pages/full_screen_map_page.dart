import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_semantic_colors.dart';

// Every colour on this page comes from `context.semanticColors`. The
// `_kDark = Color(0xFF1A1A1A)` constant and the two `Colors.white` fills that
// used to sit here are gone — they were EasyRepair values that ignored the
// dark palette entirely, so this page rendered a white bar over a dark app.

/// One reusable in-app full-screen map, opened from the client's Track Ustaad
/// view.
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
    final c = context.semanticColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.textPrimary,
        // A 1px hairline instead of a shadow — the same separation every other
        // HandyGo surface uses.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: c.textPrimary,
          ),
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
///
/// Sits *over* a map rather than inside a screen, so it keeps a hairline
/// border to stay legible against arbitrary map tiles — the same treatment
/// the Track Ustaad page's floating banner uses.
class MapExpandButton extends StatelessWidget {
  final VoidCallback onTap;

  const MapExpandButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          // 44 — the prototype's minimum tappable control.
          width: 44,
          height: 44,
          child: Icon(
            Icons.fullscreen_rounded,
            size: 22,
            color: c.textPrimary,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/location/location_availability.dart';
import '../../../../core/location/location_recovery_snack.dart';
import '../../../../core/permissions/file_validation_helper.dart';
import '../../../../core/permissions/media_permission_helper.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../features/bookings/domain/entities/attachable_inspection_entity.dart';
import '../../../../features/bookings/domain/entities/booking_entity.dart';
import '../../../../features/bookings/domain/entities/create_booking_request.dart';
import '../../../../features/bookings/domain/entities/update_booking_request.dart';
import '../../../../features/bookings/presentation/pages/choose_ustaad_page.dart';
import '../../../../features/bookings/presentation/pages/worker_discovery_map_page.dart';
import '../../../../features/bookings/presentation/providers/booking_providers.dart';
import '../../../../features/bookings/presentation/widgets/media_attachment_widgets.dart';
import '../../../../features/categories/domain/entities/service_category_entity.dart';
import '../../../../features/categories/domain/entities/standard_service_entity.dart';
import '../../../../features/categories/presentation/providers/categories_providers.dart';
import '../../../../features/saved_addresses/data/datasources/saved_addresses_remote_datasource.dart';
import '../../../../features/saved_addresses/domain/entities/saved_address_entity.dart';
import '../../../../features/saved_addresses/presentation/providers/saved_addresses_providers.dart';
import '../../../../core/services/geocoding_service.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/service_card.dart';
import '../../../../core/l10n/l10n_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../providers/booking_wizard_rules.dart';

// Booking visuals resolve exclusively through the current semantic theme.
Color _primary(BuildContext context) => context.semanticColors.primary;
Color _urgent(BuildContext context) => context.semanticColors.urgent;
Color _textPrimary(BuildContext context) => context.semanticColors.textPrimary;
Color _textSecondary(BuildContext context) =>
    context.semanticColors.textSecondary;
Color _border(BuildContext context) => context.semanticColors.border;
Color _surface(BuildContext context) => context.semanticColors.surface;
Color _surfaceSubtle(BuildContext context) =>
    context.semanticColors.surfaceSubtle;
Color _background(BuildContext context) => context.semanticColors.background;
Color _controlBorder(BuildContext context) =>
    context.semanticColors.controlBorder;
Color _softTeal(BuildContext context) => context.semanticColors.softTeal;
Color _error(BuildContext context) => context.semanticColors.error;
Color _onPrimary(BuildContext context) => context.semanticColors.onPrimary;
const _kMaxVideoSecs = 30;
const _kKarachiPreviewCenter = LatLng(24.8607, 67.0011);

final bookingMapPreviewPositionProvider = FutureProvider<LatLng?>((ref) async {
  final position = await resolvePassiveLocationPreview();
  if (position == null) return null;
  return LatLng(position.latitude, position.longitude);
});

typedef BookingAddressCoordinatesResolver =
    Future<LatLng?> Function(String address);
typedef BookingAddressLabelResolver =
    Future<String?> Function(double latitude, double longitude);
typedef BookingCurrentLocationResolver =
    Future<LocationAvailabilityResult> Function();

final bookingAddressCoordinatesResolverProvider =
    Provider<BookingAddressCoordinatesResolver>((ref) {
      return (address) async {
        final location = await GeocodingService.coordinatesFromAddress(address);
        if (location == null) return null;
        return LatLng(location.latitude, location.longitude);
      };
    });

final bookingAddressLabelResolverProvider =
    Provider<BookingAddressLabelResolver>((ref) {
      return GeocodingService.addressFromCoordinates;
    });

final bookingCurrentLocationResolverProvider =
    Provider<BookingCurrentLocationResolver>((ref) {
      return resolveCurrentLocation;
    });

class BookServicePage extends ConsumerStatefulWidget {
  final String? preselectedService;
  final bool urgentEntry;

  /// When non-null, the page operates in edit mode and pre-fills the form from
  /// the existing booking identified by this id.
  final String? editBookingId;

  const BookServicePage({
    super.key,
    this.preselectedService,
    this.editBookingId,
    this.urgentEntry = false,
  });

  @override
  ConsumerState<BookServicePage> createState() => _BookServicePageState();
}

class _BookServicePageState extends ConsumerState<BookServicePage>
    with TickerProviderStateMixin {
  // ── Form state ──────────────────────────────────────────────────────────────
  String? _selectedService;

  /// OPTIONAL previous inspection report attached to a BIDDING job — purely
  /// informational context for bidders. Null means "no report attached",
  /// which is the normal case and leaves posting behaviour unchanged.
  AttachableInspectionEntity? _attachedInspection;

  bool _isUrgent = false;
  bool _hasUrgencyChoice = false;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String? _urgentOption;

  final _titleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  double? _gpsLat;
  double? _gpsLng;
  String? _pickedAddress;
  String _selectedCity = '';
  String? _selectedSavedAddressId;
  bool _showSaveAddressOptions = false;
  bool _locationLoading = false;
  bool _addressResolving = false;
  String? _addressResolutionError;
  Timer? _addressResolutionDebounce;
  int _addressResolutionGeneration = 0;
  LatLng _initialMapPreviewCenter = _kKarachiPreviewCenter;

  bool _isSubmitting = false;
  int _currentStep = 0;
  BookingEntity? _createdBooking;

  BookingLane? _laneChoice;
  // Multi-select STANDARD-lane services, keyed by service id, insertion order
  // preserved (LinkedHashMap semantics of Dart's default Map) so the sent
  // standardServiceIds list matches the order the client tapped them in.
  final Map<String, StandardServiceEntity> _selectedStandardServices = {};

  // Edit mode only: standardServiceId values carried over from the booking
  // being edited, applied to _selectedStandardServices once the real catalog
  // entries load (see _buildStandardServicesSection).
  List<String>? _pendingStandardServiceIdsToPreselect;
  bool _standardServicesPreselected = false;

  double get _selectedStandardServicesTotal => _selectedStandardServices.values
      .fold<double>(0, (sum, s) => sum + s.price);

  // ── New file attachments (locally picked, not yet uploaded) ─────────────────
  final _picker = ImagePicker();
  final List<XFile> _newAttachments = [];

  // ── Existing attachments from API (edit mode) ───────────────────────────────
  List<BookingAttachmentEntity> _existingAttachments = [];
  final Set<String> _removedAttachmentIds = {};

  // ── Voice note — new recording ───────────────────────────────────────────────
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _voiceNotePath;

  // ── Voice note — existing (edit mode) ────────────────────────────────────────
  BookingAttachmentEntity? _existingVoiceNote;

  // ── Recording pulse animation ─────────────────────────────────────────────
  // Initialized eagerly in initState (not via a lazy `late` initializer) so
  // dispose() always operates on an already-created controller rather than
  // constructing one for the first time on a deactivated state.
  late final AnimationController _pulseCtrl;

  bool _preselectionApplied = false;
  ProviderSubscription<AsyncValue<dynamic>>? _categoriesSubscription;

  bool _prefillDone = false;

  bool get _isEditMode => widget.editBookingId != null;

  bool get _isFixedPriceDetailsStep =>
      _currentStep == 2 && _laneChoice == BookingLane.standard;

  late final String _bookingAttemptId = _newUuidV4();

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _selectedService = widget.preselectedService;
    final initial = BookingWizardInitialState.fresh(
      urgentEntry: widget.urgentEntry && !_isEditMode,
    );
    _laneChoice = initial.lane;
    _hasUrgencyChoice = initial.urgency != null;
    _isUrgent = initial.urgency == BookingUrgency.urgent;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final preview = await ref.read(bookingMapPreviewPositionProvider.future);
      if (!mounted || preview == null) return;
      setState(() => _initialMapPreviewCenter = preview);
    });

    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final bookingAsync = ref.read(
          bookingDetailProvider(widget.editBookingId!),
        );
        bookingAsync.whenData((booking) {
          if (!_prefillDone) _prefillFromBooking(booking);
        });

        ref.listenManual(bookingDetailProvider(widget.editBookingId!), (
          _,
          next,
        ) {
          if (!mounted || _prefillDone) return;
          next.whenData((booking) {
            if (!_prefillDone) _prefillFromBooking(booking);
          });
        }, fireImmediately: false);
      });
    }

    if (!_isEditMode && widget.preselectedService != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _categoriesSubscription = ref.listenManual(
          clientBookingCategoriesProvider,
          (_, next) {
            if (!mounted || _preselectionApplied) return;
            next.whenData((categories) {
              if (_preselectionApplied || !mounted) return;
              final preselected = widget.preselectedService!;
              final hasMatch = categories.any(
                (c) => c.name.toLowerCase() == preselected.toLowerCase(),
              );
              if (hasMatch) {
                setState(() {
                  _selectedService = preselected;
                  _preselectionApplied = true;
                });
                _categoriesSubscription?.close();
                _categoriesSubscription = null;
              }
            });
          },
          fireImmediately: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _addressResolutionDebounce?.cancel();
    _categoriesSubscription?.close();
    _titleCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    _recorder.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Edit prefill ─────────────────────────────────────────────────────────────
  void _prefillFromBooking(BookingEntity booking) {
    _prefillDone = true;

    final voiceAttachments = booking.attachments
        .where((a) => a.type == AttachmentType.audio)
        .toList();
    final mediaAttachments = booking.attachments
        .where((a) => a.type != AttachmentType.audio)
        .toList();

    setState(() {
      _selectedService = booking.serviceCategory;
      _isUrgent = booking.urgency == BookingUrgency.urgent;
      _hasUrgencyChoice = true;
      _selectedDate = booking.scheduledDate;
      _addressCtrl.text = booking.address ?? '';
      _selectedCity = booking.city;

      // STANDARD/INSPECTION come straight from the booking's own lane field.
      // Only bookings predating that field (no explicit lane, no inspection
      // flag) need the legacy text-prefix fallback to resolve to inspection.
      _laneChoice = booking.lane == BookingLane.standard
          ? BookingLane.standard
          : (booking.inspection || booking.hasLegacyInspectionPrefix)
          ? BookingLane.inspection
          : BookingLane.bidding;
      _titleCtrl.text = booking.title ?? '';
      _descriptionCtrl.text = booking.cleanDescription ?? '';

      if (_laneChoice == BookingLane.standard) {
        final ids = booking.standardServiceItems
            .map((i) => i.standardServiceId)
            .whereType<String>()
            .toList();
        _pendingStandardServiceIdsToPreselect = ids.isNotEmpty
            ? ids
            : (booking.standardServiceId != null
                  ? [booking.standardServiceId!]
                  : const []);
      }

      _gpsLat = booking.latitude != 0 ? booking.latitude : null;
      _gpsLng = booking.longitude != 0 ? booking.longitude : null;

      if (booking.timeSlot != null) {
        _selectedTimeSlot = booking.timeSlot!.label;
      }
      if (booking.urgentWindow != null) {
        _urgentOption = booking.urgentWindow!.label;
      }

      _existingAttachments = List.of(mediaAttachments);
      _existingVoiceNote = voiceAttachments.isNotEmpty
          ? voiceAttachments.first
          : null;
    });
  }

  // ── Scheduling helpers ────────────────────────────────────────────────────
  int _slotStartHour(String slot) {
    switch (slot) {
      case 'Morning':
        return 9;
      case 'Afternoon':
        return 12;
      case 'Evening':
        return 16;
      case 'Night':
        return 20;
      default:
        return 9;
    }
  }

  String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  DateTime? _scheduledAtForSelection() {
    if (_selectedDate == null || _selectedTimeSlot == null) return null;
    return scheduledAtForTimeSlot(
      _selectedDate!,
      _slotEnum(_selectedTimeSlot!),
    );
  }

  TimeSlot _slotEnum(String slot) {
    switch (slot) {
      case 'Morning':
        return TimeSlot.morning;
      case 'Afternoon':
        return TimeSlot.afternoon;
      case 'Evening':
        return TimeSlot.evening;
      case 'Night':
        return TimeSlot.night;
      default:
        return TimeSlot.morning;
    }
  }

  String _computeLiveSummary() {
    if (!_hasUrgencyChoice) {
      return context.l10n.postJobSelectBookingTypeFirst;
    }
    if (_isUrgent) {
      return context.l10n.postJobOffersSoon;
    }
    if (_selectedDate == null || _selectedTimeSlot == null) {
      return context.l10n.postJobSelectDateTimeFirst;
    }
    final liveHour = _slotStartHour(_selectedTimeSlot!) - 1;
    final liveTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      liveHour,
    );
    final timeStr = DateFormat('h:mm a').format(liveTime);
    final dateStr = DateFormat('d MMMM').format(_selectedDate!);
    return context.l10n.postJobGoesLiveAt(timeStr, dateStr);
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────────
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _urgent(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Attachment logic ──────────────────────────────────────────────────────
  int get _totalAttachmentCount =>
      _existingAttachments.length -
      _existingAttachments
          .where((a) => _removedAttachmentIds.contains(a.id))
          .length +
      _newAttachments.length;

  Future<void> _pickAttachment() async {
    if (_totalAttachmentCount >= 4) return;
    final choice = await _showMediaTypeSheet();
    if (choice == null || !mounted) return;
    await _handleMediaChoice(choice);
  }

  // Opens the device camera. Offers both photo and video capture — uses the
  // already-present image_picker package, no additional package required.
  Future<void> _pickFromCamera() async {
    if (_totalAttachmentCount >= 4) return;
    final choice = await _showCameraTypeSheet();
    if (choice == null || !mounted) return;
    await _handleMediaChoice(choice);
  }

  Future<void> _handleMediaChoice(String choice) async {
    XFile? file;
    switch (choice) {
      case 'gallery_image':
        file = await pickImageWithRecovery(
          context,
          picker: _picker,
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      case 'gallery_video':
        file = await _pickVideoWithRecovery(source: ImageSource.gallery);
        if (file != null && !await _checkVideoDuration(file)) {
          if (mounted) {
            _showError(context.l10n.postJobVideoTooLong(_kMaxVideoSecs));
          }
          return;
        }
      case 'camera_photo':
        file = await pickImageWithRecovery(
          context,
          picker: _picker,
          source: ImageSource.camera,
          imageQuality: 85,
        );
      case 'camera_video':
        file = await _pickVideoWithRecovery(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: _kMaxVideoSecs),
        );
    }
    if (file == null || !mounted) return;

    final validationError = await validateBookingAttachment(
      File(file.path),
      _mimeTypeForFile(file),
    );
    if (validationError != null) {
      if (mounted) {
        _showError(
          validationError == FileValidationError.tooLarge
              ? context.l10n.fileTooLargeMessage
              : context.l10n.unsupportedFileMessage,
        );
      }
      return;
    }

    setState(() => _newAttachments.add(file!));
  }

  /// [pickVideo] has the same permission-failure shape as [pickImage] but
  /// image_picker doesn't expose a shared helper for it — mirrors
  /// [pickImageWithRecovery]'s permission handling for video capture.
  Future<XFile?> _pickVideoWithRecovery({
    required ImageSource source,
    Duration? maxDuration,
  }) async {
    final kind = source == ImageSource.camera
        ? MediaPermissionKind.camera
        : MediaPermissionKind.gallery;
    final permission = kind == MediaPermissionKind.camera
        ? Permission.camera
        : Permission.photos;

    if ((await permission.status).isPermanentlyDenied) {
      if (mounted) {
        _showMediaPermissionSnack(kind, permanentlyDenied: true);
      }
      return null;
    }

    try {
      return await _picker.pickVideo(source: source, maxDuration: maxDuration);
    } on PlatformException catch (e) {
      final isPermissionIssue =
          e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied' ||
          e.code == 'no_available_camera';
      if (!mounted) return null;
      if (isPermissionIssue) {
        final nowStatus = await permission.status;
        if (mounted) {
          _showMediaPermissionSnack(
            kind,
            permanentlyDenied: nowStatus.isPermanentlyDenied,
          );
        }
      } else {
        _showError(context.l10n.errorUnknown);
      }
      return null;
    }
  }

  void _showMediaPermissionSnack(
    MediaPermissionKind kind, {
    required bool permanentlyDenied,
  }) {
    final message = kind == MediaPermissionKind.camera
        ? context.l10n.cameraPermissionDeniedMessage
        : context.l10n.galleryPermissionDeniedMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _urgent(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: permanentlyDenied
            ? SnackBarAction(
                label: context.l10n.commonOpenSettings,
                onPressed: openAppSettings,
                textColor: _onPrimary(context),
              )
            : null,
      ),
    );
  }

  Future<bool> _checkVideoDuration(XFile file) async {
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.file(File(file.path));
      await ctrl.initialize();
      return ctrl.value.duration.inSeconds <= _kMaxVideoSecs;
    } catch (_) {
      return true;
    } finally {
      await ctrl?.dispose();
    }
  }

  Future<String?> _showMediaTypeSheet() {
    return _showPickerSheet(
      title: context.l10n.postJobAddPhotoVideo,
      options: [
        (
          icon: Icons.image_rounded,
          label: context.l10n.postJobChoosePhoto,
          value: 'gallery_image',
        ),
        (
          icon: Icons.videocam_rounded,
          label: context.l10n.postJobChooseVideo,
          value: 'gallery_video',
        ),
      ],
    );
  }

  Future<String?> _showCameraTypeSheet() {
    return _showPickerSheet(
      title: context.l10n.postJobCamera,
      options: [
        (
          icon: Icons.camera_alt_rounded,
          label: context.l10n.chatTakePhoto,
          value: 'camera_photo',
        ),
        (
          icon: Icons.videocam_rounded,
          label: context.l10n.postJobRecordVideo30,
          value: 'camera_video',
        ),
      ],
    );
  }

  Future<String?> _showPickerSheet({
    required String title,
    required List<({IconData icon, String label, String value})> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final opt in options)
              ListTile(
                leading: Icon(opt.icon, color: _primary(context)),
                title: Text(opt.label),
                onTap: () => Navigator.pop(context, opt.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Location logic ────────────────────────────────────────────────────────
  void _cancelManualAddressResolution() {
    _addressResolutionDebounce?.cancel();
    _addressResolutionGeneration++;
    _addressResolving = false;
    _addressResolutionError = null;
  }

  void _onManualAddressChanged(String value) {
    _addressResolutionDebounce?.cancel();
    final generation = ++_addressResolutionGeneration;
    final query = value.trim();

    setState(() {
      _gpsLat = null;
      _gpsLng = null;
      _pickedAddress = null;
      _selectedCity = '';
      _selectedSavedAddressId = null;
      _addressResolutionError = null;
      _addressResolving = query.length >= 4;
    });

    if (query.length < 4) return;
    _addressResolutionDebounce = Timer(const Duration(milliseconds: 750), () {
      _resolveTypedAddress(query, generation);
    });
  }

  Future<void> _resolveTypedAddress(String query, int generation) async {
    try {
      final location = await ref.read(
        bookingAddressCoordinatesResolverProvider,
      )(query);
      if (!mounted || generation != _addressResolutionGeneration) return;
      if (location == null) {
        setState(() {
          _addressResolving = false;
          _addressResolutionError = context.l10n.postJobAddressUnresolved;
        });
        return;
      }

      final resolvedAddress =
          await ref.read(bookingAddressLabelResolverProvider)(
            location.latitude,
            location.longitude,
          ) ??
          query;
      if (!mounted || generation != _addressResolutionGeneration) return;

      setState(() {
        _gpsLat = location.latitude;
        _gpsLng = location.longitude;
        _pickedAddress = resolvedAddress;
        _selectedCity = '';
        _selectedSavedAddressId = null;
        _addressResolving = false;
        _addressResolutionError = null;
        _addressCtrl.value = TextEditingValue(
          text: resolvedAddress,
          selection: TextSelection.collapsed(offset: resolvedAddress.length),
        );
      });
    } catch (_) {
      if (!mounted || generation != _addressResolutionGeneration) return;
      setState(() {
        _addressResolving = false;
        _addressResolutionError = context.l10n.postJobAddressUnresolved;
      });
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      // DIAG-1: API key presence
      final key = AppConfig.googleMapsApiKey;
      if (key.isEmpty) {
        debugPrint(
          '[ReverseGeocode] ERROR: googleMapsApiKey is EMPTY — '
          'check dart-define GOOGLE_MAPS_API_KEY',
        );
        return null;
      } else {
        final masked = key.length > 8
            ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
            : '****';
        debugPrint('[ReverseGeocode] API key loaded (masked): $masked');
      }

      // DIAG-2: request URL (key masked)
      final maskedKey = key.length > 8
          ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
          : '****';
      debugPrint(
        '[ReverseGeocode] Request URL: '
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$maskedKey',
      );

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$key',
      );
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      // DIAG-3: HTTP status
      debugPrint('[ReverseGeocode] HTTP status: ${response.statusCode}');

      final body = await response.transform(utf8.decoder).join();
      client.close();

      // DIAG-4: raw response body (truncated to 500 chars)
      debugPrint(
        '[ReverseGeocode] Raw body (first 500 chars): '
        '${body.length > 500 ? body.substring(0, 500) : body}',
      );

      final json = jsonDecode(body) as Map<String, dynamic>;
      final status = json['status'] as String? ?? 'UNKNOWN';

      // DIAG-5: parsed geocode status
      debugPrint('[ReverseGeocode] Geocode status: $status');

      if (status != 'OK') {
        final errMsg = json['error_message'] as String? ?? '';
        if (status == 'REQUEST_DENIED') {
          debugPrint(
            '[ReverseGeocode] ERROR: REQUEST_DENIED — '
            'Google Geocoding API is likely not enabled for this key, '
            'or the key is invalid/restricted. error_message: $errMsg',
          );
        } else {
          debugPrint(
            '[ReverseGeocode] Non-OK status "$status". '
            'error_message: $errMsg',
          );
        }
        return null;
      }

      final results = json['results'] as List<dynamic>;
      if (results.isEmpty) {
        debugPrint('[ReverseGeocode] status=OK but results list is empty');
        return null;
      }

      final addr = results.first['formatted_address'] as String?;

      // DIAG-6: final parsed address
      debugPrint('[ReverseGeocode] Parsed address: $addr');
      return addr;
    } catch (e, st) {
      debugPrint('[ReverseGeocode] Exception: $e\n$st');
    }
    return null;
  }

  Future<void> _captureCurrentLocation() async {
    _cancelManualAddressResolution();
    setState(() => _locationLoading = true);
    try {
      final locationResult = await ref.read(
        bookingCurrentLocationResolverProvider,
      )();
      if (!locationResult.isAvailable) {
        if (mounted) {
          showLocationRecoverySnack(
            context,
            locationResult.status,
            onRetry: _captureCurrentLocation,
          );
        }
        return;
      }
      final pos = locationResult.position!;
      debugPrint(
        '[CaptureLocation] GPS position: lat=${pos.latitude}, lng=${pos.longitude}',
      );

      // Primary: Google Geocoding HTTP API.
      var addr = await _reverseGeocode(pos.latitude, pos.longitude);

      // Fallback: device-native geocoder (no HTTP API key required) — covers
      // cases where the HTTP call fails (key restrictions, quota, network).
      if (addr == null) {
        debugPrint(
          '[CaptureLocation] HTTP reverse geocode failed, trying native geocoding fallback',
        );
        addr = await ref.read(bookingAddressLabelResolverProvider)(
          pos.latitude,
          pos.longitude,
        );
      }

      // Last resort: never leave the address field empty after a successful
      // GPS fix — mirrors the "Pick on Map" flow, which always shows a label.
      addr ??=
          'Current location (${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)})';

      debugPrint('[CaptureLocation] final resolved address: $addr');

      if (mounted) {
        setState(() {
          _gpsLat = pos.latitude;
          _gpsLng = pos.longitude;
          _pickedAddress = addr;
          _selectedCity = '';
          _selectedSavedAddressId = null;
          _addressCtrl.text = addr!;
        });
      }
    } catch (_) {
      if (mounted) _showError(context.l10n.postJobLocationRetrieveFailed);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _openMapPicker() async {
    _cancelManualAddressResolution();
    final initial = (_gpsLat != null && _gpsLng != null)
        ? PickedLocation(
            latitude: _gpsLat!,
            longitude: _gpsLng!,
            address: _pickedAddress ?? _addressCtrl.text.trim(),
          )
        : null;

    final result = await showLocationPicker(context, initial: initial);
    if (result != null && mounted) {
      setState(() {
        _gpsLat = result.latitude;
        _gpsLng = result.longitude;
        _pickedAddress = result.address;
        _selectedCity = '';
        _selectedSavedAddressId = null;
        if (_addressCtrl.text.trim().isEmpty || _pickedAddress != null) {
          _addressCtrl.text = result.address;
        }
      });
    }
  }

  // ── Voice note logic ──────────────────────────────────────────────────────

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  String _fmtSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showError(
          'Microphone access is permanently denied. Enable it in Settings.',
        );
        openAppSettings();
      }
      return;
    }
    if (!status.isGranted) {
      if (mounted) _showError(context.l10n.inspFormMicDenied);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _pulseCtrl.repeat(reverse: true);
    _startRecordingTimer();
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
  }

  Future<void> _stopAndFinalize() async {
    final path = await _recorder.stop();
    _pulseCtrl.stop();
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _voiceNotePath = path;
      _recordingSeconds = 0;
    });
  }

  Future<void> _cancelRecording() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    _pulseCtrl.stop();
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _voiceNotePath = null;
      _recordingSeconds = 0;
    });
  }

  Future<void> _deleteVoiceNote() async {
    if (_voiceNotePath != null) {
      final file = File(_voiceNotePath!);
      if (await file.exists()) await file.delete();
    }
    setState(() => _voiceNotePath = null);
  }

  void _removeExistingVoiceNote() {
    if (_existingVoiceNote == null) return;
    setState(() {
      _removedAttachmentIds.add(_existingVoiceNote!.id);
      _existingVoiceNote = null;
    });
  }

  // Description sent to the backend is always exactly what the client typed
  // — the inspection choice is carried separately via the `inspection`
  // boolean field, not encoded into this text.
  String? _buildEffectiveDescription() {
    if (_laneChoice == BookingLane.inspection) {
      final sees = _descriptionCtrl.text.trim();
      return sees.isEmpty ? null : sees;
    }
    if (_laneChoice == BookingLane.standard) {
      return null;
    }
    final details = _descriptionCtrl.text.trim();
    if (details.isNotEmpty) return details;
    return _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim();
  }

  String? _buildEffectiveTitle() {
    if (_laneChoice == BookingLane.inspection) {
      return _selectedService;
    }
    if (_laneChoice == BookingLane.standard) {
      if (_selectedStandardServices.isEmpty) return _selectedService;
      return _selectedStandardServices.values.map((s) => s.name).join(', ');
    }
    return _titleCtrl.text.trim().isEmpty
        ? _selectedService
        : _titleCtrl.text.trim();
  }

  // Maps the selected urgent-window option label to the API enum value.
  UrgentWindow? _urgentWindowFromOption(String? option) {
    return switch (option) {
      'Within 1 hour' => UrgentWindow.within1Hour,
      'Within 2 hours' => UrgentWindow.within2Hours,
      'Within 4 hours' => UrgentWindow.within4Hours,
      _ => null,
    };
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _validateAndSubmit() async {
    if (_isSubmitting) return;

    if (_selectedService == null) {
      _showError(context.l10n.postJobSelectService);
      return;
    }

    if (_laneChoice == null) {
      _showError(context.l10n.postJobSelectOption);
      return;
    }

    if (_laneChoice == BookingLane.bidding &&
        _titleCtrl.text.trim().length <= 3) {
      _showError(context.l10n.postJobDescribeIssue);
      return;
    }

    if (_laneChoice == BookingLane.inspection &&
        _descriptionCtrl.text.trim().isEmpty) {
      _showError(context.l10n.postJobInspectionDescriptionRequired);
      return;
    }

    if (_laneChoice == BookingLane.bidding &&
        _voiceNotePath == null &&
        _existingVoiceNote == null) {
      _showError(context.l10n.postJobCustomVoiceRequired);
      return;
    }

    if (_laneChoice == BookingLane.standard &&
        _selectedStandardServices.isEmpty) {
      _showError(context.l10n.postJobSelectStandardService);
      return;
    }

    if (!_hasUrgencyChoice) {
      _showError(context.l10n.postJobSelectBookingTypeFirst);
      return;
    } else if (!_isUrgent) {
      if (_selectedDate == null) {
        _showError(context.l10n.postJobSelectDate);
        return;
      }
      if (_selectedTimeSlot == null) {
        _showError(context.l10n.postJobSelectArrivalWindow);
        return;
      }
    } else {
      if (_urgentOption == null) {
        _showError(context.l10n.postJobSelectUrgencyWindow);
        return;
      }
    }

    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      _showError(context.l10n.postJobEnterAddress);
      return;
    }

    if (_gpsLat == null ||
        _gpsLng == null ||
        (_gpsLat == 0.0 && _gpsLng == 0.0)) {
      _showError(context.l10n.postJobAddLocationFirst);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isEditMode) {
        final updatedBooking = await _submitEdit(address);
        if (!mounted) return;
        if (updatedBooking.lane == BookingLane.standard) {
          // STANDARD edits skip the generic "Booking Updated!" modal and go
          // straight back to worker selection — same page used right after
          // creating a STANDARD booking — since sub-services/price may have
          // just changed and the client still needs to (re)pick an Ustaad.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChooseUstaadPage(booking: updatedBooking),
            ),
          );
        } else {
          await _showSuccessDialog();
        }
      } else {
        await _submitCreate(address);
        if (mounted) _goToNextPage();
      }
    } catch (e) {
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCreate(String address) async {
    debugPrint('[BookingSubmit] serviceCategory="$_selectedService"');
    final request = CreateBookingRequest(
      serviceCategory: _selectedService!,
      urgency: _isUrgent ? BookingUrgency.urgent : BookingUrgency.normal,
      timeSlot: (!_isUrgent && _selectedTimeSlot != null)
          ? _slotEnum(_selectedTimeSlot!)
          : null,
      urgentWindow: _isUrgent ? _urgentWindowFromOption(_urgentOption) : null,
      scheduledAt: _isUrgent ? null : _scheduledAtForSelection(),
      title: _buildEffectiveTitle(),
      description: _buildEffectiveDescription(),
      addressLine: address,
      city: _selectedCity,
      latitude: _gpsLat,
      longitude: _gpsLng,
      inspection: _laneChoice == BookingLane.inspection,
      lane: _laneChoice ?? BookingLane.bidding,
      // Only ever sent for a BIDDING job, and only when the client picked
      // one; the backend re-validates ownership/category regardless.
      attachedInspectionBookingId: _laneChoice == BookingLane.bidding
          ? _attachedInspection?.bookingId
          : null,
      standardServiceIds: _laneChoice == BookingLane.standard
          ? _selectedStandardServices.keys.toList()
          : const [],
      idempotencyKey: _bookingAttemptId,
    );

    final booking = await ref
        .read(createBookingNotifierProvider.notifier)
        .submit(request);
    _createdBooking = booking;
    await _uploadNewAttachments(booking.id);
    await _uploadVoiceNote(booking.id);
  }

  Future<BookingEntity> _submitEdit(String address) async {
    final updateRequest = UpdateBookingRequest(
      bookingId: widget.editBookingId!,
      serviceCategory: _selectedService,
      title: _buildEffectiveTitle(),
      description: _buildEffectiveDescription(),
      urgency: _isUrgent ? BookingUrgency.urgent : BookingUrgency.normal,
      timeSlot: (!_isUrgent && _selectedTimeSlot != null)
          ? _slotEnum(_selectedTimeSlot!)
          : null,
      urgentWindow: _isUrgent ? _urgentWindowFromOption(_urgentOption) : null,
      scheduledAt: _isUrgent ? null : _scheduledAtForSelection(),
      addressLine: address,
      city: _selectedCity,
      latitude: _gpsLat,
      longitude: _gpsLng,
      inspection: _laneChoice == BookingLane.inspection,
      standardServiceIds: _laneChoice == BookingLane.standard
          ? _selectedStandardServices.keys.toList()
          : null,
    );

    final updated = await ref
        .read(updateBookingNotifierProvider.notifier)
        .submitUpdate(updateRequest);

    for (final id in _removedAttachmentIds) {
      final result = await ref
          .read(bookingRepositoryProvider)
          .deleteAttachment(widget.editBookingId!, id);
      result.fold((failure) => throw failure, (_) {});
    }

    await _uploadNewAttachments(widget.editBookingId!);
    await _uploadVoiceNote(widget.editBookingId!);

    return updated;
  }

  Future<void> _uploadNewAttachments(String bookingId) async {
    for (final xfile in _newAttachments) {
      final file = File(xfile.path);
      final mimeType = _mimeTypeForFile(xfile);
      final result = await ref
          .read(bookingRepositoryProvider)
          .uploadAttachment(bookingId, file, mimeType);
      result.fold((failure) => throw failure, (_) {});
    }
  }

  Future<void> _uploadVoiceNote(String bookingId) async {
    if (_voiceNotePath == null) return;
    final file = File(_voiceNotePath!);
    if (!file.existsSync()) return;
    final result = await ref
        .read(bookingRepositoryProvider)
        .uploadAttachment(
          bookingId,
          file,
          'audio/x-m4a',
          durationSeconds: _recordingSeconds > 0
              ? _recordingSeconds.toDouble()
              : null,
        );
    result.fold((failure) => throw failure, (_) {});
  }

  String _mimeTypeForFile(XFile file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.mov')) return 'video/quicktime';
    return file.mimeType ?? 'application/octet-stream';
  }

  String _friendlyError(Object e) {
    if (e is NetworkFailure) {
      return context.l10n.errorNoInternet;
    }
    if (e is Failure) {
      return e.message.isNotEmpty ? e.message : context.l10n.postJobSaveFailed;
    }
    if (e.toString().contains('SocketException')) {
      return context.l10n.errorNoInternet;
    }
    return context.l10n.postJobSaveFailed;
  }

  // After a successful new booking, skip the success dialog and go straight
  // to the next lane-specific page: STANDARD/INSPECTION bookings open the
  // fixed-price Choose Ustaad page, while BIDDING keeps the existing
  // Find Workers / live offers page — same navigation pattern used by the
  // "Find Workers" button on the booking card.
  void _goToNextPage() {
    final booking = _createdBooking;
    if (booking == null) {
      context.go('/client/jobs');
      return;
    }
    if (booking.lane == BookingLane.standard ||
        booking.lane == BookingLane.inspection) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChooseUstaadPage(booking: booking)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkerDiscoveryMapPage(booking: booking),
        ),
      );
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: _primary(context),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.postJobBookingUpdatedTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.postJobBookingUpdatedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary(context),
                    foregroundColor: _onPrimary(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.postJobViewBooking,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section card wrapper ──────────────────────────────────────────────────
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _textPrimary(context).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary(context),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _inspectionSectionCard({
    Key? key,
    required String title,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border(context)),
        boxShadow: [
          BoxShadow(
            color: _textPrimary(context).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _infoNote(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  // ── Image path lookup for service cards (mirrors kServices in service_data) ──
  // Returns null for unknown services, which falls back to emoji layout in ServiceCard.
  String? _serviceImagePath(String name) {
    return switch (name.toLowerCase()) {
      'ac technician' => 'assets/images/ac.jpg',
      'electrician' => 'assets/images/electrician.jpg',
      'plumber' => 'assets/images/plumber.jpg',
      'handyman' => 'assets/images/handyman.jpg',
      'cleaner' || 'cleaning' => 'assets/images/deepcleaning.png',
      'painter' => 'assets/images/painting.jpg',
      'carpenter' => 'assets/images/carpenter.jpg',
      'appliances repair' => 'assets/images/appliance.png',
      'pest control' => 'assets/images/pest.png',
      'car wash' => 'assets/images/carwash.png',
      'gardener' => 'assets/images/gardening.jpg',
      _ => null,
    };
  }

  // ── A. Service selection — shown when no service was preselected (e.g.
  // "Book Urgently", which pushes straight to this page with no category) ──
  Widget _buildServiceSection() {
    final categoriesAsync = ref.watch(clientBookingCategoriesProvider);

    return _sectionCard(
      title: context.l10n.postJobSelectService,
      child: categoriesAsync.when(
        loading: () => SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: _primary(context),
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, _) => SizedBox(
          height: 40,
          child: Center(
            child: Text(
              context.l10n.postJobServicesLoadFailed,
              style: TextStyle(fontSize: 13, color: _textSecondary(context)),
            ),
          ),
        ),
        data: (categories) {
          // Use the same responsive GridView + aspect-ratio approach as the
          // home page so image-based cards render without overflow.
          return LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 2;
              const spacing = 12.0;
              const cardBaseW = 170.0;

              final cardWidth =
                  (constraints.maxWidth - spacing) / crossAxisCount;
              final imageHeight = cardWidth / 1.6;
              final titleSize = rFont(
                cardWidth,
                15,
                min: 13,
                max: 17,
                baseWidth: cardBaseW,
              );
              final subtitleSize = rFont(
                cardWidth,
                12,
                min: 11,
                max: 13,
                baseWidth: cardBaseW,
              );
              final textAreaHeight =
                  20.0 + titleSize * 1.6 + 3.0 + subtitleSize * 1.6 + 6.0;
              final childAspectRatio =
                  cardWidth / (imageHeight + textAreaHeight);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  return ServiceCard(
                    title: cat.name,
                    emoji: cat.emoji,
                    backgroundColor: categoryBgColor(cat.name),
                    emojiBackgroundColor: categoryEmojiBgColor(cat.name),
                    imagePath: _serviceImagePath(cat.name),
                    isSelected: _selectedService == cat.name,
                    locked: !kLaunchActiveServiceCategories.contains(cat.name),
                    onTap: () => setState(() {
                      // Switching service invalidates any attached report:
                      // the backend requires the report's category to match
                      // the job's, so keeping it would guarantee a rejection
                      // at submit. Cleared explicitly (never silently kept
                      // and never silently mismatched) and the client is
                      // told, so they can re-attach a matching one.
                      if (_selectedService != cat.name &&
                          _attachedInspection != null) {
                        _attachedInspection = null;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showError(
                              context.l10n.postJobInspectionReportCleared,
                            );
                          }
                        });
                      }
                      _selectedService = cat.name;
                      // A category change clears any previous lane choice.
                      // Even inspection-only categories require the client to
                      // tap the visible Inspection option explicitly.
                      _laneChoice = null;
                    }),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── B. Job type toggle ────────────────────────────────────────────────────
  Widget _buildJobTypeToggle() {
    return _sectionCard(
      title: context.l10n.postJobBookingType,
      child: Row(
        children: [
          _jobTypeBtn(label: context.l10n.postJobNormal, urgentMode: false),
          const SizedBox(width: 10),
          _jobTypeBtn(label: context.l10n.postJobUrgent, urgentMode: true),
        ],
      ),
    );
  }

  Widget _jobTypeBtn({required String label, required bool urgentMode}) {
    final colors = context.semanticColors;
    final selected = _hasUrgencyChoice && _isUrgent == urgentMode;
    final activeColor = urgentMode ? colors.urgent : colors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _hasUrgencyChoice = true;
          _isUrgent = urgentMode;
          _selectedTimeSlot = null;
          _urgentOption = null;
          _selectedDate = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.softTeal : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? activeColor : _border(context),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                urgentMode ? Icons.bolt_rounded : Icons.access_time_rounded,
                size: 16,
                color: activeColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.textPrimary : activeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── C. Scheduling (includes live timing summary at bottom) ────────────────
  Widget _buildSchedulingSection() {
    final colors = context.semanticColors;
    return _sectionCard(
      title: context.l10n.postJobDateTime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_hasUrgencyChoice)
            Text(
              context.l10n.postJobSelectBookingTypeFirst,
              style: TextStyle(color: colors.textSecondary),
            )
          else if (_isUrgent)
            _buildUrgentSchedule()
          else
            _buildNormalSchedule(),
          const SizedBox(height: 12),
          _buildLiveSummary(),
        ],
      ),
    );
  }

  Widget _buildNormalSchedule() {
    // The slot ids stay English: they drive _slotStartHour, _slotEnum and the
    // _selectedTimeSlot state, so translating them would break scheduling.
    // Only the labels and descriptions below are shown to the user.
    const slots = ['Morning', 'Afternoon', 'Evening', 'Night'];
    final slotLabel = {
      'Morning': context.l10n.slotMorning,
      'Afternoon': context.l10n.slotAfternoon,
      'Evening': context.l10n.slotEvening,
      'Night': context.l10n.slotNight,
    };
    final slotDesc = {
      'Morning': context.l10n.slotMorningRange,
      'Afternoon': context.l10n.slotAfternoonRange,
      'Evening': context.l10n.slotEveningRange,
      'Night': context.l10n.slotNightRange,
    };

    Widget slotChip(String slot) {
      final sel = _selectedTimeSlot == slot;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _selectedTimeSlot = slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _primary(context) : _surfaceSubtle(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? _primary(context) : _border(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slotLabel[slot]!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? _onPrimary(context) : _textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slotDesc[slot]!,
                  style: TextStyle(
                    fontSize: 11,
                    color: sel
                        ? _onPrimary(context).withValues(alpha: 0.70)
                        : _textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colors = context.semanticColors;
    final today = DateTime.now();
    final dates = List<DateTime>.generate(
      6,
      (index) => DateTime(today.year, today.month, today.day + index),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.postJobDay,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final date = dates[index];
              final selected =
                  _selectedDate != null &&
                  DateUtils.isSameDay(_selectedDate, date);
              final dayLabel = index == 0
                  ? context.l10n.commonToday
                  : index == 1
                  ? context.l10n.postJobTomorrow
                  : DateFormat('EEE').format(date);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? colors.softTeal : colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? colors.primary : colors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.postJobArrivalTime,
          style: TextStyle(fontSize: 13, color: _textSecondary(context)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            slotChip(slots[0]),
            const SizedBox(width: 8),
            slotChip(slots[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            slotChip(slots[2]),
            const SizedBox(width: 8),
            slotChip(slots[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildUrgentSchedule() {
    const options = ['Within 1 hour', 'Within 2 hours', 'Within 4 hours'];
    final optionLabels = {
      'Within 1 hour': context.l10n.urgentWithin1Hour,
      'Within 2 hours': context.l10n.urgentWithin2Hours,
      'Within 4 hours': context.l10n.urgentWithin4Hours,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...options.map((opt) {
          final sel = _urgentOption == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _urgentOption = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? _urgent(context).withValues(alpha: 0.07)
                      : _surfaceSubtle(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? _urgent(context) : _border(context),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: sel ? _urgent(context) : _textSecondary(context),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      optionLabels[opt]!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? _urgent(context) : _textPrimary(context),
                      ),
                    ),
                    if (sel) ...[
                      const Spacer(),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: _urgent(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        _infoNote(
          context.l10n.postJobNearbyNotifiedNow,
          color: _urgent(context),
        ),
      ],
    );
  }

  // ── F. Location ───────────────────────────────────────────────────────────
  String _normalizeSavedAddressLabel(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  SavedAddressDraft? _currentAddressDraft(String label) {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty ||
        _gpsLat == null ||
        _gpsLng == null ||
        (_gpsLat == 0 && _gpsLng == 0)) {
      _showError(context.l10n.postJobCompleteAddressBeforeSaving);
      return null;
    }
    return SavedAddressDraft(
      label: label.trim(),
      addressLine: address,
      city: _selectedCity,
      latitude: _gpsLat!,
      longitude: _gpsLng!,
    );
  }

  void _useSavedAddress(SavedAddressEntity address) {
    _cancelManualAddressResolution();
    setState(() {
      _selectedSavedAddressId = address.id;
      _addressCtrl.text = address.addressLine;
      _pickedAddress = address.addressLine;
      _selectedCity = address.city;
      _gpsLat = address.latitude;
      _gpsLng = address.longitude;
    });
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final colors = context.semanticColors;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveCurrentAddressAs(String rawLabel) async {
    final label = rawLabel.trim();
    if (label.isEmpty) return;
    final draft = _currentAddressDraft(label);
    if (draft == null) return;

    final addresses = ref.read(savedAddressesProvider).valueOrNull ?? const [];
    SavedAddressEntity? existing;
    final normalized = _normalizeSavedAddressLabel(label);
    for (final row in addresses) {
      if (row.normalizedLabel == normalized) {
        existing = row;
        break;
      }
    }

    try {
      if (existing != null) {
        final confirmed = await _confirmDialog(
          title: context.l10n.savedAddressUpdateTitle(existing.label),
          body: context.l10n.savedAddressUpdateBody(existing.label),
          confirmLabel: context.l10n.savedAddressUpdateAction,
        );
        if (!confirmed || !mounted) return;
        final updated = await ref
            .read(savedAddressesProvider.notifier)
            .updateAddress(existing.id, draft);
        if (!mounted) return;
        _useSavedAddress(updated);
      } else {
        final created = await ref
            .read(savedAddressesProvider.notifier)
            .create(draft);
        if (!mounted) return;
        _useSavedAddress(created);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.savedAddressSaved)));
      }
    } catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  Future<String?> _showSavedAddressNameSheet({
    String initialValue = '',
    required String title,
    SavedAddressEntity? editing,
    String? initialError,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? inlineError = initialError;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: context.l10n.savedAddressName,
                    errorText: inlineError,
                  ),
                  onChanged: (_) {
                    if (inlineError != null) {
                      setSheetState(() => inlineError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        setSheetState(
                          () => inlineError =
                              context.l10n.savedAddressNameRequired,
                        );
                        return;
                      }
                      final normalized = _normalizeSavedAddressLabel(value);
                      final rows =
                          ref.read(savedAddressesProvider).valueOrNull ??
                          const <SavedAddressEntity>[];
                      final conflicts = rows.any(
                        (row) =>
                            row.id != editing?.id &&
                            row.normalizedLabel == normalized,
                      );
                      if (editing != null && conflicts) {
                        setSheetState(
                          () => inlineError =
                              context.l10n.savedAddressRenameConflict,
                        );
                        return;
                      }
                      Navigator.pop(sheetContext, value);
                    },
                    child: Text(context.l10n.commonSave),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _askOtherSavedAddressName() async {
    final label = await _showSavedAddressNameSheet(
      title: context.l10n.savedAddressCustomNameTitle,
    );
    if (label != null && mounted) await _saveCurrentAddressAs(label);
  }

  Future<void> _renameSavedAddress(
    SavedAddressEntity address, {
    String? initialValue,
    String? initialError,
  }) async {
    final nextLabel = await _showSavedAddressNameSheet(
      initialValue: initialValue ?? address.label,
      title: context.l10n.savedAddressRenameTitle,
      editing: address,
      initialError: initialError,
    );
    if (nextLabel == null || !mounted) return;

    try {
      await ref
          .read(savedAddressesProvider.notifier)
          .updateAddress(
            address.id,
            SavedAddressDraft(
              label: nextLabel,
              addressLine: address.addressLine,
              city: address.city,
              latitude: address.latitude,
              longitude: address.longitude,
            ),
          );
    } catch (error) {
      if (!mounted) return;
      if (error is Failure && error.code == FailureCode.conflict) {
        ref.invalidate(savedAddressesProvider);
        try {
          await ref.read(savedAddressesProvider.future);
        } catch (_) {
          // The server already rejected the conflicting rename; the inline
          // localized error remains authoritative even if refresh is offline.
        }
        if (!mounted) return;
        await _renameSavedAddress(
          address,
          initialValue: nextLabel,
          initialError: context.l10n.savedAddressRenameConflict,
        );
        return;
      }
      _showError(_friendlyError(error));
    }
  }

  Future<void> _deleteSavedAddress(SavedAddressEntity address) async {
    final confirmed = await _confirmDialog(
      title: context.l10n.savedAddressDeleteTitle,
      body: context.l10n.savedAddressDeleteBody(address.label),
      confirmLabel: context.l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(savedAddressesProvider.notifier).delete(address.id);
      if (mounted && _selectedSavedAddressId == address.id) {
        setState(() => _selectedSavedAddressId = null);
      }
    } catch (error) {
      if (mounted) _showError(_friendlyError(error));
    }
  }

  Future<void> _manageSavedAddress(SavedAddressEntity address) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.location_on_outlined),
              title: Text(context.l10n.savedAddressUse),
              onTap: () => Navigator.pop(sheetContext, 'use'),
            ),
            ListTile(
              leading: Icon(Icons.sync_rounded),
              title: Text(context.l10n.savedAddressUpdateWithCurrent),
              onTap: () => Navigator.pop(sheetContext, 'update'),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text(context.l10n.savedAddressRename),
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: context.semanticColors.error,
              ),
              title: Text(context.l10n.commonDelete),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'use') {
      _useSavedAddress(address);
    } else if (action == 'update') {
      final draft = _currentAddressDraft(address.label);
      if (draft == null) return;
      try {
        final updated = await ref
            .read(savedAddressesProvider.notifier)
            .updateAddress(address.id, draft);
        if (mounted) _useSavedAddress(updated);
      } catch (error) {
        if (mounted) _showError(_friendlyError(error));
      }
    } else if (action == 'rename') {
      await _renameSavedAddress(address);
    } else if (action == 'delete') {
      await _deleteSavedAddress(address);
    }
  }

  Widget _buildSavedAddressesRow() {
    final addresses = ref.watch(savedAddressesProvider).valueOrNull ?? const [];
    if (addresses.isEmpty) return const SizedBox.shrink();
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.savedAddresses,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final address = addresses[index];
                final selected = _selectedSavedAddressId == address.id;
                return InputChip(
                  selected: selected,
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(address.label, overflow: TextOverflow.ellipsis),
                  ),
                  onPressed: () => _useSavedAddress(address),
                  onDeleted: () => _manageSavedAddress(address),
                  deleteIcon: Icon(Icons.more_horiz, size: 20),
                  backgroundColor: colors.surface,
                  selectedColor: colors.softTeal,
                  side: BorderSide(
                    color: selected ? colors.primary : colors.border,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final colors = context.semanticColors;
    final addresses = ref.watch(savedAddressesProvider).valueOrNull ?? const [];
    final hasHome = addresses.any((row) => row.normalizedLabel == 'home');
    final hasOffice = addresses.any((row) => row.normalizedLabel == 'office');
    final hasResolvedLocation = _gpsLat != null && _gpsLng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.postJobAddressIntro,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.postJobCompleteAddressLabel,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _addressCtrl,
                onChanged: _onManualAddressChanged,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (value) {
                  final query = value.trim();
                  if (query.length < 4) return;
                  _addressResolutionDebounce?.cancel();
                  final generation = ++_addressResolutionGeneration;
                  setState(() => _addressResolving = true);
                  _resolveTypedAddress(query, generation);
                },
                decoration: InputDecoration(
                  hintText: context.l10n.postJobAddressHint,
                  hintStyle: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                  suffixIcon: _addressResolving
                      ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                        )
                      : hasResolvedLocation
                      ? Icon(
                          Icons.check_circle,
                          color: colors.success,
                          size: 20,
                        )
                      : null,
                  errorText: _addressResolutionError,
                  helperText: _addressResolutionError == null
                      ? (_addressResolving
                            ? context.l10n.postJobAddressResolving
                            : context.l10n.postJobAddressLandmarkHelper)
                      : null,
                  helperMaxLines: 2,
                  errorMaxLines: 2,
                  filled: true,
                  fillColor: colors.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.controlBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.controlBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _locationLoading ? null : _captureCurrentLocation,
                icon: _locationLoading
                    ? SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  context.l10n.postJobCurrentLocation,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(
                  context.l10n.postJobPickOnMap,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: BorderSide(color: colors.controlBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAddressMapPreview(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSavedAddressesRow(),
              CheckboxListTile(
                value: _showSaveAddressOptions,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(context.l10n.savedAddressForNextTime),
                onChanged: (value) =>
                    setState(() => _showSaveAddressOptions = value ?? false),
              ),
              if (_showSaveAddressOptions) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!hasHome)
                      ActionChip(
                        label: Text(context.l10n.navHome),
                        onPressed: () => _saveCurrentAddressAs('Home'),
                      ),
                    if (!hasOffice)
                      ActionChip(
                        label: Text(context.l10n.savedAddressOffice),
                        onPressed: () => _saveCurrentAddressAs('Office'),
                      ),
                    ActionChip(
                      label: Text(context.l10n.workerCancelReasonOther),
                      onPressed: _askOtherSavedAddressName,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressMapPreview() {
    final colors = context.semanticColors;
    final hasSelectedLocation = _gpsLat != null && _gpsLng != null;
    final cameraTarget = hasSelectedLocation
        ? LatLng(_gpsLat!, _gpsLng!)
        : _initialMapPreviewCenter;

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              key: ValueKey(
                'address-preview-${cameraTarget.latitude}-'
                '${cameraTarget.longitude}-$hasSelectedLocation',
              ),
              initialCameraPosition: CameraPosition(
                target: cameraTarget,
                zoom: hasSelectedLocation ? 15.5 : 13.5,
              ),
              markers: hasSelectedLocation
                  ? {
                      Marker(
                        markerId: const MarkerId('selected-address'),
                        position: cameraTarget,
                      ),
                    }
                  : const {},
              liteModeEnabled: true,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
          ),
          Positioned.fill(
            child: Material(
              color: colors.surface.withValues(alpha: 0),
              child: InkWell(onTap: _openMapPicker),
            ),
          ),
          PositionedDirectional(
            start: 10,
            end: 10,
            bottom: 9,
            child: Material(
              color: colors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: _openMapPicker,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasSelectedLocation
                            ? Icons.location_on_rounded
                            : Icons.map_outlined,
                        color: colors.primary,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasSelectedLocation
                              ? (_pickedAddress ?? _addressCtrl.text.trim())
                              : context.l10n.postJobMapPreviewEmpty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── G. Voice note + attachments (combined media section) ──────────────────
  Widget _buildMediaSection() {
    final visibleExisting = _existingAttachments
        .where((a) => !_removedAttachmentIds.contains(a.id))
        .toList();
    final canAddMore = _totalAttachmentCount < 4;
    final hasMedia = visibleExisting.isNotEmpty || _newAttachments.isNotEmpty;
    final isInspection = _laneChoice == BookingLane.inspection;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing voice note row (edit mode only)
        if (_existingVoiceNote != null && _voiceNotePath == null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _primary(context).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _primary(context).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primary(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: _onPrimary(context),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.postJobVoiceAttached,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary(context),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _removeExistingVoiceNote,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: _textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // WhatsApp-style voice bar
        _buildVoiceBar(inspectionStyle: isInspection),
        const SizedBox(height: 12),

        // Static rule explanation — photos and video share one combined
        // cap of 4, never "4 photos plus a video".
        if (!isInspection) ...[
          Text(
            context.l10n.postJobAttachmentHelper,
            style: TextStyle(fontSize: 11, color: _textSecondary(context)),
          ),
          const SizedBox(height: 8),
        ],

        // Action row: file attachment + camera
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.attach_file_rounded,
                label: isInspection
                    ? context.l10n.postJobInspectionAddPhoto
                    : context.l10n.postJobAddPhotoVideo,
                onTap: canAddMore ? _pickAttachment : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.camera_alt_outlined,
                label: context.l10n.postJobCamera,
                onTap: canAddMore ? _pickFromCamera : null,
              ),
            ),
          ],
        ),

        // Media previews (larger, 2-col, tap to expand)
        if (hasMedia) ...[
          const SizedBox(height: 14),
          _buildAttachmentPreviews(visibleExisting),
        ],

        const SizedBox(height: 8),
        Text(
          isInspection
              ? context.l10n.postJobInspectionAttachmentCount(
                  _totalAttachmentCount,
                )
              : context.l10n.postJobAttachmentCount(_totalAttachmentCount),
          style: TextStyle(fontSize: 11, color: _textSecondary(context)),
        ),
        if (_removedAttachmentIds.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.postJobAttachmentsWillBeRemoved(
              _removedAttachmentIds.length,
            ),
            style: TextStyle(fontSize: 11, color: _urgent(context)),
          ),
        ],
      ],
    );

    return isInspection
        ? _inspectionSectionCard(
            key: const ValueKey('inspection-media-card'),
            title: context.l10n.postJobInspectionVoiceHeading,
            child: content,
          )
        : _sectionCard(
            title: context.l10n.postJobCustomVoiceAndPhotos,
            child: content,
          );
  }

  Widget _buildCustomMediaSection() {
    final colors = context.semanticColors;
    final visibleExisting = _existingAttachments
        .where((attachment) => !_removedAttachmentIds.contains(attachment.id))
        .toList();
    final canAddMore = _totalAttachmentCount < 4;
    final hasMedia = visibleExisting.isNotEmpty || _newAttachments.isNotEmpty;
    final hasVoiceNote = _voiceNotePath != null || _existingVoiceNote != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: context.l10n.postJobCustomVoiceLabel,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ' · ${context.l10n.postJobCustomRequired}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 9),
          if (_existingVoiceNote != null && _voiceNotePath == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.successSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: colors.onPrimary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.l10n.postJobVoiceAttached,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.success,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _removeExistingVoiceNote,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            _buildVoiceBar(),
          const SizedBox(height: 10),
          Text(
            context.l10n.postJobAttachmentHelper,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.photo_outlined,
                  label: context.l10n.postJobCustomAddPhotos,
                  onTap: canAddMore ? _pickAttachment : null,
                  outlined: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: context.l10n.postJobCamera,
                  onTap: canAddMore ? _pickFromCamera : null,
                  outlined: true,
                ),
              ),
            ],
          ),
          if (hasMedia) ...[
            const SizedBox(height: 12),
            _buildCustomAttachmentPreviews(visibleExisting),
          ],
          const SizedBox(height: 8),
          Text(
            hasVoiceNote
                ? context.l10n.postJobCustomMediaAttached(_totalAttachmentCount)
                : context.l10n.postJobCustomMediaPending(_totalAttachmentCount),
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          if (_removedAttachmentIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.postJobAttachmentsWillBeRemoved(
                _removedAttachmentIds.length,
              ),
              style: TextStyle(fontSize: 11, color: colors.urgent),
            ),
          ],
        ],
      ),
    );
  }

  // WhatsApp-style voice note bar — 3 states: idle, recording, preview.
  Widget _buildVoiceBar({bool inspectionStyle = false}) {
    // ── State: preview ready — player with inline delete icon ────────────
    if (_voiceNotePath != null) {
      return WhatsAppVoiceNotePlayer(
        localPath: _voiceNotePath,
        onDelete: _deleteVoiceNote,
      );
    }

    // ── State: recording — trash | dot+timer | waveform | stop/save ──────
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border(context)),
        ),
        child: Row(
          children: [
            // Trash
            _VoiceBarBtn(
              onTap: _cancelRecording,
              child: Icon(
                Icons.delete_outline_rounded,
                color: _textSecondary(context),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            // Pulsing red dot
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, _) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _error(
                    context,
                  ).withValues(alpha: 0.5 + _pulseCtrl.value * 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Timer
            Text(
              _fmtSeconds(_recordingSeconds),
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            // Animated waveform
            Expanded(child: _AnimatedWaveform(animation: _pulseCtrl)),
            const SizedBox(width: 8),
            // Stop & save (tap to finalize recording immediately)
            _VoiceBarBtn(
              onTap: _stopAndFinalize,
              bg: _primary(context).withValues(alpha: 0.12),
              child: Icon(
                Icons.pause_rounded,
                color: _primary(context),
                size: 20,
              ),
            ),
          ],
        ),
      );
    }

    // ── State: idle ───────────────────────────────────────────────────────
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: inspectionStyle
              ? _primary(context).withValues(alpha: 0.09)
              : _surfaceSubtle(context),
          borderRadius: BorderRadius.circular(inspectionStyle ? 14 : 50),
          border: inspectionStyle ? null : Border.all(color: _border(context)),
        ),
        child: Row(
          children: [
            if (inspectionStyle)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _primary(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 16,
                  color: _onPrimary(context),
                ),
              )
            else
              Icon(
                Icons.mic_none_rounded,
                size: 18,
                color: _textSecondary(context),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                inspectionStyle
                    ? context.l10n.postJobInspectionRecordPrompt
                    : context.l10n.postJobTapToRecord,
                style: TextStyle(
                  fontSize: 12,
                  color: inspectionStyle
                      ? _primary(context)
                      : _textSecondary(context),
                ),
              ),
            ),
            if (!inspectionStyle)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 16,
                  color: _primary(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool outlined = false,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: BoxDecoration(
          color: outlined ? _surface(context) : _surfaceSubtle(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? _border(context)
                : _border(context).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled ? _primary(context) : _textSecondary(context),
            ),
            const SizedBox(width: 6),
            // Flexible + ellipsis rather than shrinking the font: this button
            // sits in a half-width Expanded next to the Camera button, and a
            // longer translation (or a narrow Android screen) must never
            // overflow the row.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? _textPrimary(context)
                      : _textSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2-column preview grid with tap-to-expand and ×-remove.
  Widget _buildAttachmentPreviews(
    List<BookingAttachmentEntity> visibleExisting,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileW = (constraints.maxWidth - 12) / 2;
        final tileH = tileW * 0.72; // ~4:3

        final tiles = <Widget>[
          ...visibleExisting.asMap().entries.map((e) {
            final attachment = e.value;
            final isVideo = attachment.type == AttachmentType.video;
            return _buildPreviewTile(
              w: tileW,
              h: tileH,
              isVideo: isVideo,
              networkUrl: attachment.url,
              onTap: () => _openPreviewDialog(
                networkUrl: attachment.url,
                isVideo: isVideo,
              ),
              onRemove: () =>
                  setState(() => _removedAttachmentIds.add(attachment.id)),
            );
          }),
          ..._newAttachments.asMap().entries.map((e) {
            final idx = e.key;
            final file = e.value;
            final isVideo =
                file.mimeType?.startsWith('video') == true ||
                file.path.toLowerCase().endsWith('.mp4') ||
                file.path.toLowerCase().endsWith('.mov');
            return _buildPreviewTile(
              w: tileW,
              h: tileH,
              isVideo: isVideo,
              localPath: file.path,
              onTap: () =>
                  _openPreviewDialog(localPath: file.path, isVideo: isVideo),
              onRemove: () => setState(() => _newAttachments.removeAt(idx)),
            );
          }),
        ];

        return Wrap(spacing: 12, runSpacing: 12, children: tiles);
      },
    );
  }

  Widget _buildCustomAttachmentPreviews(
    List<BookingAttachmentEntity> visibleExisting,
  ) {
    final tiles = <Widget>[
      ...visibleExisting.map((attachment) {
        final isVideo = attachment.type == AttachmentType.video;
        return _buildPreviewTile(
          w: 72,
          h: 64,
          compact: true,
          isVideo: isVideo,
          networkUrl: attachment.url,
          onTap: () =>
              _openPreviewDialog(networkUrl: attachment.url, isVideo: isVideo),
          onRemove: () =>
              setState(() => _removedAttachmentIds.add(attachment.id)),
        );
      }),
      ..._newAttachments.asMap().entries.map((entry) {
        final index = entry.key;
        final file = entry.value;
        final isVideo =
            file.mimeType?.startsWith('video') == true ||
            file.path.toLowerCase().endsWith('.mp4') ||
            file.path.toLowerCase().endsWith('.mov');
        return _buildPreviewTile(
          w: 72,
          h: 64,
          compact: true,
          isVideo: isVideo,
          localPath: file.path,
          onTap: () =>
              _openPreviewDialog(localPath: file.path, isVideo: isVideo),
          onRemove: () => setState(() => _newAttachments.removeAt(index)),
        );
      }),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: tiles);
  }

  Widget _buildPreviewTile({
    required double w,
    required double h,
    required bool isVideo,
    String? localPath,
    String? networkUrl,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    bool compact = false,
  }) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 9 : 12),
              child: SizedBox.expand(
                child: isVideo
                    ? Container(
                        color: _textPrimary(context),
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: _onPrimary(context).withValues(alpha: 0.54),
                          size: 40,
                        ),
                      )
                    : localPath != null
                    ? Image.file(File(localPath), fit: BoxFit.cover)
                    : networkUrl != null
                    ? Image.network(
                        networkUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: _surfaceSubtle(context),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _textSecondary(context),
                          ),
                        ),
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : Container(
                                color: _surfaceSubtle(context),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _primary(context),
                                  ),
                                ),
                              ),
                      )
                    : Container(color: _surfaceSubtle(context)),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: InkResponse(
              onTap: onRemove,
              radius: 22,
              child: SizedBox(
                width: compact ? 32 : 44,
                height: compact ? 32 : 44,
                child: Center(
                  child: Container(
                    width: compact ? 20 : 28,
                    height: compact ? 20 : 28,
                    decoration: BoxDecoration(
                      color: _textPrimary(context).withValues(alpha: 0.54),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: compact ? 13 : 16,
                      color: _onPrimary(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Full-screen preview dialog with × close button.
  // Supports local files (new attachments) and network URLs (existing).
  void _openPreviewDialog({
    String? localPath,
    String? networkUrl,
    required bool isVideo,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: _textPrimary(context).withValues(alpha: 0.87),
      builder: (ctx) => Scaffold(
        backgroundColor: _textPrimary(context),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: isVideo
                    ? Icon(
                        Icons.play_circle_fill_rounded,
                        size: 80,
                        color: _onPrimary(context).withValues(alpha: 0.38),
                      )
                    : localPath != null
                    ? InteractiveViewer(
                        child: Image.file(File(localPath), fit: BoxFit.contain),
                      )
                    : networkUrl != null
                    ? InteractiveViewer(
                        child: Image.network(
                          networkUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: _onPrimary(context).withValues(alpha: 0.38),
                            size: 48,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkResponse(
                  onTap: () => Navigator.of(ctx).pop(),
                  radius: 24,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _onPrimary(context).withValues(alpha: 0.24),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: _onPrimary(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── H. Live timing summary ────────────────────────────────────────────────
  Widget _buildLiveSummary() {
    final text = _computeLiveSummary();
    final isReady =
        _isUrgent || (_selectedDate != null && _selectedTimeSlot != null);
    final color = _isUrgent ? _urgent(context) : _primary(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReady
            ? color.withValues(alpha: 0.07)
            : _surfaceSubtle(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReady ? color.withValues(alpha: 0.3) : _border(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 15,
            color: isReady ? color : _textSecondary(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isReady ? color : _textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── I. Submit button (superseded by _buildStepNavButtons on step 3) ─────────
  // ignore: unused_element
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _validateAndSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary(context),
          disabledBackgroundColor: _primary(context).withValues(alpha: 0.5),
          foregroundColor: _onPrimary(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _onPrimary(context),
                ),
              )
            : Text(
                _isEditMode
                    ? context.l10n.postJobSaveChanges
                    : context.l10n.postJobBookService,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  // ── Step validation ──────────────────────────────────────────────────────────
  // Step 1 · Address
  bool _validateStep1() {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      setState(() {
        _addressResolutionError = context.l10n.postJobAddressRequired;
      });
      _showError(context.l10n.postJobAddAddressToContinue);
      return false;
    }
    if (_gpsLat == null || _gpsLng == null || (_gpsLat == 0 && _gpsLng == 0)) {
      setState(() {
        _addressResolutionError = context.l10n.postJobAddressUnresolved;
      });
      _showError(context.l10n.postJobAddLocationFirst);
      return false;
    }
    return true;
  }

  // Step 2.1 · Lane choice
  bool _validateLaneSelectStep() {
    if (_laneChoice == null) {
      _showError(context.l10n.postJobSelectOption);
      return false;
    }
    return true;
  }

  // Step 2.2 · Selected lane's details
  bool _validateLaneDetailsStep() {
    final issue = validateBookingLaneDetails(
      lane: _laneChoice,
      standardServiceCount: _selectedStandardServices.length,
      inspectionDescription: _descriptionCtrl.text,
      customTitle: _titleCtrl.text,
      hasVoiceNote: _voiceNotePath != null || _existingVoiceNote != null,
    );
    if (issue == null) return true;
    _showError(switch (issue) {
      BookingLaneDetailIssue.standardServiceRequired =>
        context.l10n.postJobSelectStandardService,
      BookingLaneDetailIssue.inspectionDescriptionRequired =>
        context.l10n.postJobInspectionDescriptionRequired,
      BookingLaneDetailIssue.customTitleRequired =>
        context.l10n.postJobDescribeIssue,
      BookingLaneDetailIssue.customVoiceRequired =>
        context.l10n.postJobCustomVoiceRequired,
    });
    return false;
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep == 1 && !_validateLaneSelectStep()) return;
    if (_currentStep == 2 && !_validateLaneDetailsStep()) return;
    if (_currentStep < 3) setState(() => _currentStep++);
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  // ── Step indicator ────────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final labels = [
      context.l10n.postJobStepAddress,
      context.l10n.postJobService,
      context.l10n.postJobStepDetails,
      context.l10n.postJobProgressBarTime,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (i) {
          final isDone = i < _currentStep;
          final isActive = i == _currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: i < 3 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    decoration: BoxDecoration(
                      color: (isDone || isActive)
                          ? _primary(context)
                          : _border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: (isDone || isActive)
                          ? _primary(context)
                          : _textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAddressProgressIndicator() {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: index < 3 ? 6 : 0),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: index == 0 ? colors.primary : colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLaneProgressIndicator() {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: index < 3 ? 5 : 0),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: index <= 1 ? colors.primary : colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCustomRequestProgressIndicator() {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: index < 3 ? 5 : 0),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: index <= 2 ? colors.primary : colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCustomRequestTextCard({
    required String label,
    required String status,
    required Color statusColor,
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required int minLines,
    required int maxLines,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ' · $status',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            maxLength: maxLength,
            textInputAction: textInputAction,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
              counterText: '',
              filled: true,
              fillColor: colors.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.controlBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.controlBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 1.4),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTitleSection() {
    return _buildCustomRequestTextCard(
      label: context.l10n.postJobCustomWorkTitleLabel,
      status: context.l10n.postJobCustomRequired,
      statusColor: _primary(context),
      controller: _titleCtrl,
      hint: context.l10n.postJobCustomWorkTitleHint,
      maxLength: 120,
      minLines: 1,
      maxLines: 2,
    );
  }

  Widget _buildCustomDetailsSection() {
    return _buildCustomRequestTextCard(
      label: context.l10n.postJobCustomDetailsLabel,
      status: context.l10n.postJobCustomOptional,
      statusColor: _textSecondary(context),
      controller: _descriptionCtrl,
      hint: context.l10n.postJobCustomDetailsHint,
      maxLength: 1000,
      minLines: 3,
      maxLines: 5,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildFixedPriceProgressIndicator() {
    final colors = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: index < 3 ? 5 : 0),
              child: Container(
                key: ValueKey('fixed-price-progress-$index'),
                height: 2,
                decoration: BoxDecoration(
                  color: index <= 2 ? colors.primary : colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: Service address ────────────────────────────────────────────────
  Widget _buildStep1() {
    // Entry points like "Book Urgently" push here with no preselected
    // service — show the category picker first so a category (and therefore
    // standard services) can actually be resolved afterward.
    final showServicePicker = !_isEditMode && _selectedService == null;

    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showServicePicker) ...[
            _buildServiceSection(),
            const SizedBox(height: 16),
          ],
          _buildLocationSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 2.1: Booking lane choice only ──────────────────────────────────────
  // Editing an existing STANDARD booking locks the lane — the 3 "what do you
  // need?" cards never show, since switching lane on an existing booking
  // isn't supported. A read-only service header replaces them instead, so
  // the client can still see which service they're editing.
  bool get _hideLaneCardsForEdit =>
      _isEditMode && _laneChoice == BookingLane.standard;

  Widget _buildLaneSelectStep() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hideLaneCardsForEdit)
            _buildLockedServiceHeader()
          else
            _buildLaneSelector(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 2.2: Selected lane's detail form ───────────────────────────────────
  // Shown only after a lane has been committed to on step 2.1 — one lane's
  // fields at a time, on their own page.
  Widget _buildLaneDetailsStep() {
    if (_laneChoice == BookingLane.standard) {
      return SingleChildScrollView(
        key: const ValueKey(2),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: _buildStandardServicesSection(),
      );
    }

    if (_laneChoice == BookingLane.bidding) {
      return _buildCustomRequestStep();
    }

    final categoriesAsync = ref.watch(clientBookingCategoriesProvider);
    final inspectionFee = categoriesAsync.maybeWhen(
      data: (categories) => _resolveCategory(categories)?.inspectionFee,
      orElse: () => null,
    );

    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: EdgeInsets.fromLTRB(
        20,
        _laneChoice == BookingLane.inspection ? 0 : 16,
        20,
        16,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_laneChoice == BookingLane.inspection) ...[
            _buildInspectionOverviewCard(fee: inspectionFee),
            const SizedBox(height: 10),
            _buildInspectionProblemField(),
            const SizedBox(height: 10),
            _buildMediaSection(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCustomRequestStep() {
    final colors = context.semanticColors;
    return SingleChildScrollView(
      key: const ValueKey('custom-request-step'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomTitleSection(),
          const SizedBox(height: 10),
          _buildCustomDetailsSection(),
          const SizedBox(height: 10),
          _buildAttachInspectionSection(),
          const SizedBox(height: 10),
          _buildCustomMediaSection(),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.postJobCustomHelperNote,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Step 3: Booking type + schedule ────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildJobTypeToggle(),
          const SizedBox(height: 16),
          _buildSchedulingSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Details step: 3-lane "What do you need?" card selector ────────────────
  ServiceCategoryEntity? _resolveCategory(
    List<ServiceCategoryEntity> categories,
  ) {
    if (_selectedService == null) return null;
    for (final c in categories) {
      if (c.name.toLowerCase() == _selectedService!.toLowerCase()) return c;
    }
    return null;
  }

  /// Replaces the lane cards when editing a STANDARD booking — shows the
  /// locked category (e.g. "Electrician") so the client still sees what
  /// they're editing, without offering to switch service or lane.
  Widget _buildLockedServiceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.build_circle_rounded,
              color: _primary(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.postJobService,
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedService ?? context.l10n.postJobService,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: _textSecondary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneSelector() {
    final categoriesAsync = ref.watch(clientBookingCategoriesProvider);
    final category = categoriesAsync.maybeWhen(
      data: _resolveCategory,
      orElse: () => null,
    );

    // Which lanes a category allows is a property OF THAT CATEGORY, so until
    // it has actually been resolved there is nothing truthful to render.
    //
    // This is the bug that made Appliances Repair show all three options: the
    // rule used to read `category?.inspectionOnly ?? false`, so an
    // unresolvable category (backend list not loaded yet, request failed, or
    // the category genuinely missing from /categories) silently degraded to
    // "every lane is allowed" — the least safe possible default — while the
    // same null simultaneously disabled the Inspection card via
    // `inspectionFee != null`. Guessing is now refused outright.
    if (category == null) {
      // Still fetching: a brief spinner, which resolves into the real options
      // the moment the list arrives. Once the list HAS arrived and the
      // category still is not in it, the spinner would never end — so that
      // case falls through to an empty section instead, and the backend
      // rejects the booking on submit as it always would.
      return _sectionCard(
        title: context.l10n.postJobWhatDoYouNeed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: categoriesAsync.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }

    final inspectionFee = category.inspectionFee;
    final inspectionOnly = category.inspectionOnly;
    final feeLabel = inspectionFee == null ? '—' : formatPkr(inspectionFee);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReferenceLaneCard(
          lane: BookingLane.standard,
          icon: Icons.build_outlined,
          title: context.l10n.postJobLaneFixedTitle,
          subtitle: context.l10n.postJobLaneFixedSubtitle,
          action: context.l10n.postJobLaneFixedAction,
          minimumHeight: 114,
          enabled: !inspectionOnly,
          body: [
            _laneBodyText(
              context.l10n.postJobLaneFixedBody,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildReferenceLaneCard(
          lane: BookingLane.inspection,
          icon: Icons.search_rounded,
          title: context.l10n.postJobLaneInspectionTitle,
          subtitle: context.l10n.postJobLaneInspectionSubtitle,
          action: context.l10n.postJobLaneInspectionAction,
          minimumHeight: 164,
          enabled: inspectionFee != null,
          body: [
            _laneBodyText(
              context.l10n.postJobLaneInspectionFeeBody(feeLabel),
              fontWeight: FontWeight.w700,
            ),
            _laneBodyText(context.l10n.postJobLaneInspectionReportBody),
            _laneBodyText(
              context.l10n.postJobLaneInspectionWaiverBody(feeLabel),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildReferenceLaneCard(
          lane: BookingLane.bidding,
          icon: Icons.chat_bubble_outline_rounded,
          title: context.l10n.postJobLaneCustomTitle,
          action: context.l10n.postJobLaneCustomAction,
          minimumHeight: 136,
          enabled: !inspectionOnly,
          body: [
            _laneBodyText(context.l10n.postJobLaneCustomBody),
            _laneBodyText(context.l10n.postJobLaneCustomRatesBody),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: _border(context).withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            context.l10n.postJobLanePriceNote,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: _textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  // ── Optional: attach a previous inspection report (BIDDING only) ──────────

  /// Read-only supporting context for bidders. Entirely optional: failures
  /// and empty results never block posting, and no report is attached unless
  /// the client explicitly picks one.
  Widget _buildAttachInspectionSection() {
    final selected = _attachedInspection;
    final colors = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: context.l10n.postJobCustomReportLabel,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ' · ${context.l10n.postJobCustomOptional}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.postJobAttachInspectionHint,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
          if (selected == null)
            OutlinedButton.icon(
              key: const ValueKey('attach-inspection-report'),
              onPressed: _openInspectionReportSelector,
              icon: Icon(Icons.attach_file_rounded, size: 16),
              label: Text(context.l10n.postJobCustomAttachReport),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.controlBorder),
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            _AttachedInspectionCard(
              inspection: selected,
              onView: () => context.push(
                '/client/booking/${selected.bookingId}/inspection-report',
              ),
              onChange: _openInspectionReportSelector,
              onRemove: () => setState(() => _attachedInspection = null),
            ),
        ],
      ),
    );
  }

  Future<void> _openInspectionReportSelector() async {
    final categories = ref.read(clientBookingCategoriesProvider).valueOrNull;
    final category = categories == null ? null : _resolveCategory(categories);

    final picked = await showModalBottomSheet<AttachableInspectionEntity>(
      context: context,
      backgroundColor: _surface(context).withValues(alpha: 0),
      isScrollControlled: true,
      builder: (_) => _InspectionReportSelectorSheet(categoryId: category?.id),
    );
    if (picked != null && mounted) {
      setState(() => _attachedInspection = picked);
    }
  }

  Widget _buildReferenceLaneCard({
    required BookingLane lane,
    required IconData icon,
    required String title,
    required String action,
    required double minimumHeight,
    required List<Widget> body,
    String? subtitle,
    bool enabled = true,
  }) {
    final selected = _laneChoice == lane;
    final colors = context.semanticColors;

    void selectLane() {
      if (!enabled) {
        if (lane == BookingLane.inspection) {
          _showError(context.l10n.postJobInspectionNotAvailable);
        }
        return;
      }
      setState(() {
        _laneChoice = lane;
        if (lane != BookingLane.standard) {
          _selectedStandardServices.clear();
        }
      });
    }

    return Semantics(
      key: ValueKey('booking-lane-${lane.name}'),
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectLane,
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: BoxConstraints(minHeight: minimumHeight),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: 0.08)
                  : colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? colors.primary
                    : colors.textSecondary.withValues(alpha: 0.62),
                width: selected ? 1.25 : 0.9,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: selected ? colors.primary : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _laneRadio(selected),
                  ],
                ),
                const SizedBox(height: 9),
                ...body,
                const SizedBox(height: 6),
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _laneBodyText(String text, {FontWeight? fontWeight}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.38,
          fontWeight: fontWeight,
          color: _textPrimary(context),
        ),
      ),
    );
  }

  // ── Step 2.2 (INSPECTION): compact fee/waiver card ────────────────────────
  Widget _buildInspectionOverviewCard({required double? fee}) {
    final formattedFee = fee == null
        ? '—'
        : formatPkr(fee).replaceFirst(' ', '\n');

    return Container(
      key: const ValueKey('inspection-fee-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _primary(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.postJobInspectionDetailsFeeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: _onPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.postJobInspectionDetailsFeeWaiver,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: _onPrimary(context).withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            formattedFee,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 20,
              height: 1.08,
              fontWeight: FontWeight.w800,
              color: _onPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionProgressIndicator() {
    final colors = context.semanticColors;
    return Padding(
      key: const ValueKey('inspection-step-progress'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: index < 3 ? 6 : 0),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: index <= 2 ? colors.primary : colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ignore: unused_element
  Widget _laneRowOption({
    required BookingLane lane,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _laneChoice == lane;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
              _laneChoice = lane;
              if (lane != BookingLane.standard) {
                _selectedStandardServices.clear();
              }
            })
          : () => _showError(subtitle),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? _primary(context).withValues(alpha: 0.05)
                : _surfaceSubtle(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _primary(context) : _border(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? _primary(context) : _surface(context),
                  borderRadius: BorderRadius.circular(11),
                  border: selected ? null : Border.all(color: _border(context)),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? _onPrimary(context)
                      : _textSecondary(context),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? _primary(context)
                            : _textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              _laneRadio(selected),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _laneSmallOption({
    required BookingLane lane,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _laneChoice == lane;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
              _laneChoice = lane;
              _selectedStandardServices.clear();
            })
          : () => _showError(subtitle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? _primary(context).withValues(alpha: 0.05)
              : _surface(context),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? _primary(context) : _border(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? _primary(context) : _surfaceSubtle(context),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 14,
                color: selected ? _onPrimary(context) : _textSecondary(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? _primary(context)
                          : _textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            _laneRadio(selected),
          ],
        ),
      ),
    );
  }

  Widget _laneRadio(bool selected) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _primary(context) : _surfaceSubtle(context),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? _primary(context)
              : _textSecondary(context).withValues(alpha: 0.65),
          width: 1,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 13, color: _onPrimary(context))
          : null,
    );
  }

  // ignore: unused_element
  Widget _laneOption({
    required BookingLane lane,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _laneChoice == lane;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
              _laneChoice = lane;
              if (lane != BookingLane.standard) {
                _selectedStandardServices.clear();
              }
            })
          : () => _showError(subtitle),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? _primary(context).withValues(alpha: 0.07)
                : _surfaceSubtle(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _primary(context) : _border(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected ? _primary(context) : _surface(context),
                      shape: BoxShape.circle,
                      border: selected
                          ? null
                          : Border.all(color: _border(context)),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: selected
                          ? _onPrimary(context)
                          : _textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? _primary(context)
                          : _textPrimary(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _textSecondary(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _surface(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: _primary(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Edit mode only: once the real catalog for this category has loaded, match
  // the booking's carried-over standardServiceId values against it and seed
  // _selectedStandardServices — same map/keying the tap handler uses, so the
  // tiles render pre-checked with no extra rebuild needed. Runs once.
  void _applyPendingStandardServicePreselection(
    List<StandardServiceEntity> services,
  ) {
    if (_standardServicesPreselected) return;
    _standardServicesPreselected = true;
    final ids = _pendingStandardServiceIdsToPreselect;
    if (ids == null || ids.isEmpty) return;
    for (final s in services) {
      if (ids.contains(s.id)) {
        _selectedStandardServices[s.id] = s;
      }
    }
  }

  // ── Lane A: Standard Services — dynamic fixed-price catalog ────────────────
  Widget _buildStandardServicesSection() {
    final categoriesAsync = ref.watch(clientBookingCategoriesProvider);
    return categoriesAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primary(context),
            ),
          ),
        ),
      ),
      error: (_, _) =>
          _fixedPriceStateMessage(context.l10n.postJobServicesUnavailable),
      data: (categories) {
        final category = _resolveCategory(categories);
        if (category == null) {
          return _fixedPriceStateMessage(
            context.l10n.postJobSelectCategoryFirst,
          );
        }
        final servicesAsync = ref.watch(standardServicesProvider(category.id));
        return servicesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary(context),
                ),
              ),
            ),
          ),
          error: (_, _) => _fixedPriceStateMessage(
            context.l10n.postJobStandardServicesUnavailable,
            onRetry: () =>
                ref.invalidate(standardServicesProvider(category.id)),
          ),
          data: (services) {
            _applyPendingStandardServicePreselection(services);
            if (services.isEmpty) {
              return _fixedPriceStateMessage(
                context.l10n.postJobNoStandardServices,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _standardServiceTile(services[i]),
                ],
                const SizedBox(height: 12),
                _buildFixedPriceLockStrip(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _fixedPriceStateMessage(String message, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _textSecondary(context),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: _primary(context)),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixedPriceLockStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softTeal(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: _primary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.postJobStandardTotalFinal,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: _primary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _standardServiceTile(StandardServiceEntity service) {
    final selected = _selectedStandardServices.containsKey(service.id);
    return Semantics(
      key: ValueKey('fixed-price-service-${service.id}'),
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          if (selected) {
            _selectedStandardServices.remove(service.id);
          } else {
            _selectedStandardServices[service.id] = service;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 50),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _softTeal(context) : _background(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _primary(context) : _controlBorder(context),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? _primary(context) : _background(context),
                  borderRadius: BorderRadius.circular(6),
                  border: selected
                      ? null
                      : Border.all(color: _controlBorder(context)),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: _onPrimary(context),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatPkr(service.price),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lane B: dynamic inspection fee strip ───────────────────────────────────
  // ignore: unused_element
  Widget _buildInspectionFeeStrip() {
    final categoriesAsync = ref.watch(clientBookingCategoriesProvider);
    return categoriesAsync.when(
      loading: () => _sectionCard(
        title: context.l10n.postJobInspectionFeeLower,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => _sectionCard(
        title: context.l10n.postJobInspectionFeeLower,
        child: Text(
          context.l10n.postJobInspectionFeeLoadFailed,
          style: TextStyle(fontSize: 13, color: _textSecondary(context)),
        ),
      ),
      data: (categories) {
        final category = _resolveCategory(categories);
        final fee = category?.inspectionFee;
        return _sectionCard(
          title: context.l10n.postJobInspectionFeeLower,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedService ?? context.l10n.postJobService,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                fee != null ? formatPkr(fee) : context.l10n.postJobNotAvailable,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _primary(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Mode B: required "What do you see?" field ──────────────────────────────
  Widget _buildInspectionProblemField() {
    return _inspectionSectionCard(
      key: const ValueKey('inspection-problem-card'),
      title: context.l10n.postJobInspectionProblemHeading,
      child: TextFormField(
        key: const ValueKey('inspection-problem-field'),
        controller: _descriptionCtrl,
        minLines: 3,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: context.l10n.postJobWhatDoYouSeeHint,
          hintStyle: TextStyle(color: _textSecondary(context), fontSize: 14),
          filled: true,
          fillColor: _surfaceSubtle(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primary(context), width: 1.4),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  // ── Step navigation buttons ───────────────────────────────────────────────────
  Widget _buildStepNavButtons() {
    if (_currentStep == 1 && !_hideLaneCardsForEdit) {
      return _buildLaneSelectionCta();
    }
    if (_isFixedPriceDetailsStep) {
      return _buildFixedPriceFooter();
    }
    if (_currentStep == 2 && _laneChoice == BookingLane.inspection) {
      return _buildInspectionDetailsCta();
    }
    if (_currentStep == 2 && _laneChoice == BookingLane.bidding) {
      return _buildCustomRequestCta();
    }

    final isLast = _currentStep == 3;
    final isFirst = _currentStep == 0;

    return Container(
      decoration: BoxDecoration(
        color: _surface(context),
        boxShadow: [
          BoxShadow(
            color: _textPrimary(context).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          if (!isFirst) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary(context),
                  side: BorderSide(color: _primary(context)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.postJobBack,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: isFirst ? 1 : 2,
            child: ElevatedButton(
              onPressed: isLast
                  ? (_isSubmitting ? null : _validateAndSubmit)
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary(context),
                disabledBackgroundColor: _primary(
                  context,
                ).withValues(alpha: 0.5),
                foregroundColor: _onPrimary(context),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isLast
                  ? (_isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _onPrimary(context),
                            ),
                          )
                        : Text(
                            _isEditMode
                                ? context.l10n.postJobSaveChanges
                                : context.l10n.postJobBookService,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ))
                  : Text(
                      context.l10n.postJobNext,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomRequestCta() {
    final colors = context.semanticColors;
    return Container(
      color: colors.surfaceSubtle,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          key: const ValueKey('custom-request-next'),
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            context.l10n.postJobNext,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedPriceFooter() {
    final hasValidSelection = _selectedStandardServices.isNotEmpty;
    return Container(
      color: _background(context),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.postJobTotal,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary(context),
                  ),
                ),
              ),
              Text(
                formatPkr(_selectedStandardServicesTotal),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('fixed-price-next'),
              onPressed: hasValidSelection ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary(context),
                disabledBackgroundColor: context.semanticColors.disabled,
                foregroundColor: _onPrimary(context),
                disabledForegroundColor: _surface(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.l10n.postJobNext,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionDetailsCta() {
    return Container(
      key: const ValueKey('inspection-details-cta'),
      color: _surfaceSubtle(context),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary(context),
            foregroundColor: _onPrimary(context),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            context.l10n.postJobNext,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildLaneSelectionCta() {
    final lane = _laneChoice;
    final label = switch (lane) {
      BookingLane.standard => context.l10n.postJobLaneFixedCta,
      BookingLane.inspection => context.l10n.postJobLaneInspectionCta,
      BookingLane.bidding => context.l10n.postJobLaneCustomCta,
      null => context.l10n.postJobLaneChooseCta,
    };

    return Container(
      color: _surfaceSubtle(context),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: lane == null ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary(context),
            disabledBackgroundColor: _border(context),
            foregroundColor: _onPrimary(context),
            disabledForegroundColor: _textSecondary(context),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingHeader(List<String> stepTitles) {
    final isLaneStep = _currentStep == 1 && !_hideLaneCardsForEdit;
    final isCustomRequestStep =
        _currentStep == 2 && _laneChoice == BookingLane.bidding;
    final isInspectionDetails =
        _currentStep == 2 && _laneChoice == BookingLane.inspection;
    final isCompactHeader =
        isLaneStep ||
        _isFixedPriceDetailsStep ||
        isInspectionDetails ||
        isCustomRequestStep;
    final title = isInspectionDetails
        ? context.l10n.postJobInspectionDetailsPageTitle
        : _isFixedPriceDetailsStep
        ? context.l10n.postJobFixedPricePageTitle
        : isCustomRequestStep
        ? context.l10n.postJobCustomRequestTitle
        : isLaneStep
        ? context.l10n.postJobLanePageTitle
        : _isEditMode
        ? context.l10n.postJobEditBooking
        : _currentStep == 0
        ? context.l10n.postJobStepAddress
        : context.l10n.postJobBookAService;
    final subtitle = isInspectionDetails
        ? context.l10n.postJobInspectionDetailsStepIndicator(
            _selectedService ?? context.l10n.postJobService,
          )
        : _isFixedPriceDetailsStep
        ? context.l10n.postJobFixedPriceStepIndicator(
            _selectedService ?? context.l10n.postJobService,
          )
        : isCustomRequestStep
        ? context.l10n.postJobCustomRequestStepIndicator(
            _selectedService ?? context.l10n.postJobService,
          )
        : isLaneStep
        ? context.l10n.postJobLaneStepIndicator(
            _selectedService ?? context.l10n.postJobService,
          )
        : context.l10n.postJobStepIndicator(
            _currentStep + 1,
            4,
            _currentStep == 0 && _selectedService != null
                ? _selectedService!
                : stepTitles[_currentStep],
          );

    return Padding(
      padding: isCompactHeader
          ? const EdgeInsets.fromLTRB(20, 10, 20, 8)
          : const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _prevStep,
            child: Container(
              width: isCompactHeader ? 32 : 40,
              height: 40,
              decoration: isCompactHeader
                  ? null
                  : BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _textPrimary(context).withValues(alpha: 0.06),
                          blurRadius: 8,
                        ),
                      ],
                    ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: isCompactHeader ? 21 : 18,
                color: _textPrimary(context),
              ),
            ),
          ),
          SizedBox(width: isCompactHeader ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompactHeader ? 16 : 20,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isCompactHeader ? 11 : 12,
                    color: _textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stepTitles = [
      context.l10n.postJobStepAddress,
      context.l10n.postJobStepLaneSelection,
      context.l10n.postJobStepDetails,
      context.l10n.postJobStepTimeSelection,
    ];

    return Scaffold(
      backgroundColor: _isFixedPriceDetailsStep
          ? _background(context)
          : _surfaceSubtle(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────────
            _buildBookingHeader(stepTitles),

            // ── Step indicator ────────────────────────────────────────────────────
            _currentStep == 0
                ? _buildAddressProgressIndicator()
                : _currentStep == 1 && !_hideLaneCardsForEdit
                ? _buildLaneProgressIndicator()
                : _isFixedPriceDetailsStep
                ? _buildFixedPriceProgressIndicator()
                : _currentStep == 2 && _laneChoice == BookingLane.inspection
                ? _buildInspectionProgressIndicator()
                : _currentStep == 2 && _laneChoice == BookingLane.bidding
                ? _buildCustomRequestProgressIndicator()
                : _buildStepIndicator(),
            const SizedBox(height: 12),

            // ── Step content ──────────────────────────────────────────────────────
            Expanded(
              child: switch (_currentStep) {
                0 => _buildStep1(),
                1 => _buildLaneSelectStep(),
                2 => _buildLaneDetailsStep(),
                _ => _buildStep3(),
              },
            ),

            // ── Navigation buttons ────────────────────────────────────────────────
            _buildStepNavButtons(),

            // Safe-area spacer so buttons clear the system navigation bar
            SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
          ],
        ),
      ),
    );
  }
}

// ── Voice bar helper widgets ──────────────────────────────────────────────────

class _VoiceBarBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color? bg;

  const _VoiceBarBtn({required this.onTap, required this.child, this.bg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg ?? _surface(context).withValues(alpha: 0),
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Animated waveform bars — used during active recording.
class _AnimatedWaveform extends StatelessWidget {
  final Animation<double> animation;
  const _AnimatedWaveform({required this.animation});

  static const _heights = [
    4.0,
    9.0,
    15.0,
    7.0,
    19.0,
    12.0,
    6.0,
    14.0,
    9.0,
    5.0,
    17.0,
    11.0,
    7.0,
    13.0,
    8.0,
    10.0,
  ];

  @override
  Widget build(BuildContext context) {
    const barCount = 24;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        return SizedBox(
          height: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final base = _heights[i % _heights.length];
              // Alternate bars pulse in opposite phases for wave effect.
              final scale = i.isEven
                  ? 0.5 + 0.5 * animation.value
                  : 1.0 - 0.4 * animation.value;
              final h = (base * scale).clamp(2.0, 20.0);
              return Expanded(
                child: Container(
                  height: h,
                  margin: i < barCount - 1
                      ? const EdgeInsetsDirectional.only(end: 2)
                      : null,
                  decoration: BoxDecoration(
                    color: _primary(context).withValues(
                      alpha:
                          0.5 +
                          0.5 *
                              (i.isEven
                                  ? animation.value
                                  : 1.0 - animation.value),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Attached inspection report card ─────────────────────────────────────────

/// The compact selected-report card shown in Post Job once a report is
/// attached. Read-only summary plus the three actions the flow needs.
class _AttachedInspectionCard extends StatelessWidget {
  final AttachableInspectionEntity inspection;
  final VoidCallback onView;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const _AttachedInspectionCard({
    required this.inspection,
    required this.onView,
    required this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final summary = inspection.summary;
    final colors = context.semanticColors;
    return Container(
      key: const ValueKey('inspection-report-attached'),
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.successSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: colors.success),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.postJobInspectionReportAttached,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inspection.categoryName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // The inspection date is always shown so the client can
                    // judge for themselves whether it is still relevant —
                    // old reports are deliberately never auto-expired.
                    Text(
                      DateFormat(
                        'd MMM yyyy',
                      ).format(inspection.inspectionDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary(context),
                      ),
                    ),
                    if (summary != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: _textSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Wrap so the three actions reflow instead of overflowing on the
          // narrowest supported screens.
          Wrap(
            spacing: 4,
            children: [
              _AttachedAction(
                label: context.l10n.discoveryViewInspectionReport,
                onTap: onView,
              ),
              _AttachedAction(
                label: context.l10n.postJobChangeInspectionReport,
                onTap: onChange,
              ),
              _AttachedAction(
                label: context.l10n.commonRemove,
                onTap: onRemove,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachedAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _AttachedAction({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: danger ? _error(context) : _primary(context),
        textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// ── Inspection report selector sheet ────────────────────────────────────────

/// Lists the client's own eligible previous inspection reports. Loading,
/// empty and error states are all self-contained: dismissing the sheet always
/// returns null, so a failure here can never block posting the job itself.
class _InspectionReportSelectorSheet extends ConsumerWidget {
  final String? categoryId;

  const _InspectionReportSelectorSheet({this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attachableInspectionsProvider(categoryId));
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.postJobSelectInspectionReport,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20),
                  color: _textSecondary(context),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomPadding),
              child: async.when(
                loading: () => Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(_primary(context)),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.postJobInspectionReportsFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          attachableInspectionsProvider(categoryId),
                        ),
                        child: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        context.l10n.postJobNoInspectionReports,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: _textSecondary(context),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return InkWell(
                        onTap: () => Navigator.pop(context, item),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: _border(context)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.fact_check_outlined,
                                size: 16,
                                color: _primary(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.categoryName,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                      ).format(item.inspectionDate),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _textSecondary(context),
                                      ),
                                    ),
                                    if (item.summary != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        item.summary!,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.3,
                                          color: _textSecondary(context),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

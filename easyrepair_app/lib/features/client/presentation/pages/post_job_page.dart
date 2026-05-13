import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/presentation/responsive_utils.dart';
import '../../../../features/bookings/domain/entities/booking_entity.dart';
import '../../../../features/bookings/domain/entities/create_booking_request.dart';
import '../../../../features/bookings/domain/entities/update_booking_request.dart';
import '../../../../features/bookings/presentation/providers/booking_providers.dart';
import '../../../../features/bookings/presentation/widgets/media_attachment_widgets.dart';
import '../../../../features/categories/presentation/providers/categories_providers.dart';
import '../widgets/client_bottom_nav_bar.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/service_card.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF0D7A5F);
const _kRed = Color(0xFFDC2626);
const _kDark = Color(0xFF1A1A1A);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF9FAFB);
const _kMaxVideoSecs = 30;

class BookServicePage extends ConsumerStatefulWidget {
  final String? preselectedService;

  /// When non-null, the page operates in edit mode and pre-fills the form from
  /// the existing booking identified by this id.
  final String? editBookingId;

  const BookServicePage({
    super.key,
    this.preselectedService,
    this.editBookingId,
  });

  @override
  ConsumerState<BookServicePage> createState() => _BookServicePageState();
}

class _BookServicePageState extends ConsumerState<BookServicePage>
    with TickerProviderStateMixin {
  // ── Form state ──────────────────────────────────────────────────────────────
  String? _selectedService;

  bool _isUrgent = false;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String? _urgentOption;

  final _titleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  double? _gpsLat;
  double? _gpsLng;
  String? _pickedAddress;
  bool _locationLoading = false;

  bool _isSubmitting = false;
  int _currentStep = 0;
  String? _createdBookingId;

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
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _preselectionApplied = false;
  ProviderSubscription<AsyncValue<dynamic>>? _categoriesSubscription;

  bool _prefillDone = false;

  bool get _isEditMode => widget.editBookingId != null;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedService = widget.preselectedService;

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
      _selectedDate = booking.scheduledDate;
      _titleCtrl.text = booking.title ?? '';
      _addressCtrl.text = booking.address ?? '';
      _descriptionCtrl.text = booking.description ?? '';
      _gpsLat = booking.latitude != 0 ? booking.latitude : null;
      _gpsLng = booking.longitude != 0 ? booking.longitude : null;

      if (booking.timeSlot != null) {
        _selectedTimeSlot = booking.timeSlot!.label;
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
    if (_isUrgent) {
      return 'Job goes live immediately after you book the service.';
    }
    if (_selectedDate == null || _selectedTimeSlot == null) {
      return 'Select a date and arrival window to see when your job goes live.';
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
    return 'Job goes live at $timeStr on $dateStr — 1 hour before the worker arrival window.';
  }

  // ── Snackbar helpers ──────────────────────────────────────────────────────
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kRed,
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

    XFile? file;
    if (choice == 'image') {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } else {
      file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        final valid = await _checkVideoDuration(file);
        if (!valid) {
          if (mounted) {
            _showError('Video must be $_kMaxVideoSecs seconds or shorter.');
          }
          return;
        }
      }
    }
    if (file != null && mounted) setState(() => _newAttachments.add(file!));
  }

  // Opens the device camera and adds the captured photo to attachments.
  // Uses the already-present image_picker package — no additional package required.
  Future<void> _pickFromCamera() async {
    if (_totalAttachmentCount >= 4) return;
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _newAttachments.add(file));
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
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: _kGreen),
              title: const Text('Photo (jpg / png)'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: _kGreen),
              title: Text('Video (mp4, max ${_kMaxVideoSecs}s)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Location logic ────────────────────────────────────────────────────────
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      // DIAG-1: API key presence
      final key = AppConfig.googleMapsApiKey;
      if (key.isEmpty) {
        debugPrint('[ReverseGeocode] ERROR: googleMapsApiKey is EMPTY — '
            'check dart-define GOOGLE_MAPS_API_KEY');
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
      debugPrint('[ReverseGeocode] Raw body (first 500 chars): '
          '${body.length > 500 ? body.substring(0, 500) : body}');

      final json = jsonDecode(body) as Map<String, dynamic>;
      final status = json['status'] as String? ?? 'UNKNOWN';

      // DIAG-5: parsed geocode status
      debugPrint('[ReverseGeocode] Geocode status: $status');

      if (status != 'OK') {
        final errMsg = json['error_message'] as String? ?? '';
        if (status == 'REQUEST_DENIED') {
          debugPrint('[ReverseGeocode] ERROR: REQUEST_DENIED — '
              'Google Geocoding API is likely not enabled for this key, '
              'or the key is invalid/restricted. error_message: $errMsg');
        } else {
          debugPrint('[ReverseGeocode] Non-OK status "$status". '
              'error_message: $errMsg');
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
    setState(() => _locationLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) _showError('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      debugPrint(
        '[CaptureLocation] GPS position: lat=${pos.latitude}, lng=${pos.longitude}',
      );
      final addr = await _reverseGeocode(pos.latitude, pos.longitude);

      // DIAG-7: address controller assignment
      debugPrint(
        '[CaptureLocation] addr from _reverseGeocode: $addr — '
        '${addr != null ? "setting _addressCtrl.text" : "address is null, field NOT updated"}',
      );

      if (mounted) {
        setState(() {
          _gpsLat = pos.latitude;
          _gpsLng = pos.longitude;
          _pickedAddress = addr;
          if (addr != null) {
            _addressCtrl.text = addr;
            debugPrint('[CaptureLocation] _addressCtrl.text set to: $addr');
          }
        });
      }
    } catch (_) {
      if (mounted) _showError('Could not retrieve location. Please try again.');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _openMapPicker() async {
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
      if (mounted) _showError('Microphone permission denied.');
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

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _validateAndSubmit() async {
    if (_isSubmitting) return;

    if (_selectedService == null) {
      _showError('Please select a service.');
      return;
    }

    if (!_isUrgent) {
      if (_selectedDate == null) {
        _showError('Please select a date.');
        return;
      }
      if (_selectedTimeSlot == null) {
        _showError('Please select an arrival window.');
        return;
      }
    } else {
      if (_urgentOption == null) {
        _showError('Please select an urgency window.');
        return;
      }
    }

    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      _showError('Please enter your address.');
      return;
    }

    setState(() => _isSubmitting = true);

    if (_gpsLat == null ||
        _gpsLng == null ||
        (_gpsLat == 0.0 && _gpsLng == 0.0)) {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 6),
            ),
          );
          if (mounted) {
            setState(() {
              _gpsLat = pos.latitude;
              _gpsLng = pos.longitude;
              _pickedAddress = null;
            });
          }
        }
      } catch (_) {
        // GPS is optional — the booking will proceed using the text address.
      }
    }

    try {
      if (_isEditMode) {
        await _submitEdit(address);
      } else {
        await _submitCreate(address);
      }
      if (mounted) await _showSuccessDialog();
    } catch (e) {
      if (mounted) _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCreate(String address) async {
    final request = CreateBookingRequest(
      serviceCategory: _selectedService!,
      urgency: _isUrgent ? BookingUrgency.urgent : BookingUrgency.normal,
      timeSlot: (!_isUrgent && _selectedTimeSlot != null)
          ? _slotEnum(_selectedTimeSlot!)
          : null,
      scheduledAt: (!_isUrgent && _selectedDate != null) ? _selectedDate : null,
      title: _titleCtrl.text.trim().isEmpty
          ? _selectedService
          : _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      addressLine: address,
      latitude: _gpsLat,
      longitude: _gpsLng,
    );

    final booking = await ref
        .read(createBookingNotifierProvider.notifier)
        .submit(request);
    _createdBookingId = booking.id;
    await _uploadNewAttachments(booking.id);
    await _uploadVoiceNote(booking.id);
  }

  Future<void> _submitEdit(String address) async {
    final updateRequest = UpdateBookingRequest(
      bookingId: widget.editBookingId!,
      serviceCategory: _selectedService,
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      urgency: _isUrgent ? BookingUrgency.urgent : BookingUrgency.normal,
      timeSlot: (!_isUrgent && _selectedTimeSlot != null)
          ? _slotEnum(_selectedTimeSlot!)
          : null,
      scheduledAt: (!_isUrgent && _selectedDate != null) ? _selectedDate : null,
      addressLine: address,
      latitude: _gpsLat,
      longitude: _gpsLng,
    );

    await ref
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
        .uploadAttachment(bookingId, file, 'audio/x-m4a');
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
      return 'No internet connection. Please check your network.';
    }
    if (e is Failure) {
      return e.message.isNotEmpty
          ? e.message
          : 'Unable to save booking. Please try again.';
    }
    if (e.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Unable to save booking. Please try again.';
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
                  color: _kGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _kGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isEditMode ? 'Booking Updated!' : 'Booking Submitted!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEditMode
                    ? 'Your booking details have been updated successfully.'
                    : _isUrgent
                    ? 'Your job is live! Workers nearby will be notified immediately.'
                    : 'Your job has been scheduled. Workers will be notified 1 hour before the arrival window.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kGray,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (_isEditMode) {
                      context.pop();
                    } else if (_createdBookingId != null) {
                      context.go('/client/booking/$_createdBookingId');
                    } else {
                      context.go('/client/jobs');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isEditMode ? 'View Booking' : 'View My Bookings',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 14),
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
      _ => null,
    };
  }

  // ── A. Service selection ──────────────────────────────────────────────────
  Widget _buildServiceSection() {
    final categoriesAsync = ref.watch(clientBookingCategoriesProvider);

    return _sectionCard(
      title: 'Select Service',
      child: categoriesAsync.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
          ),
        ),
        error: (_, _) => const SizedBox(
          height: 40,
          child: Center(
            child: Text(
              'Failed to load services. Please restart the app.',
              style: TextStyle(fontSize: 13, color: _kGray),
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
              final titleSize =
                  rFont(cardWidth, 15, min: 13, max: 17, baseWidth: cardBaseW);
              final subtitleSize =
                  rFont(cardWidth, 12, min: 11, max: 13, baseWidth: cardBaseW);
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
                    onTap: () => setState(() => _selectedService = cat.name),
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
      title: 'Job Type',
      child: Row(
        children: [
          _jobTypeBtn(label: 'Normal', urgentMode: false),
          const SizedBox(width: 10),
          _jobTypeBtn(label: 'Urgent', urgentMode: true),
        ],
      ),
    );
  }

  Widget _jobTypeBtn({required String label, required bool urgentMode}) {
    final selected = _isUrgent == urgentMode;
    final activeColor = urgentMode ? _kRed : _kGreen;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isUrgent = urgentMode;
          _selectedTimeSlot = null;
          _urgentOption = null;
          _selectedDate = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? activeColor : _kBorder,
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
                color: selected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : activeColor,
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
    return _sectionCard(
      title: 'Schedule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isUrgent ? _buildUrgentSchedule() : _buildNormalSchedule(),
          const SizedBox(height: 12),
          _buildLiveSummary(),
        ],
      ),
    );
  }

  Widget _buildNormalSchedule() {
    const slots = ['Morning', 'Afternoon', 'Evening', 'Night'];
    const slotDesc = {
      'Morning': '9 AM – 12 PM',
      'Afternoon': '12 PM – 4 PM',
      'Evening': '4 PM – 8 PM',
      'Night': '8 PM – 11 PM',
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
              color: sel ? _kGreen : _kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? _kGreen : _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _kDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slotDesc[slot]!,
                  style: TextStyle(
                    fontSize: 11,
                    color: sel ? Colors.white70 : _kGray,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 60)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: _kGreen),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: _kGreen,
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedDate == null
                      ? 'Select a date'
                      : DateFormat('EEEE, d MMMM yyyy').format(_selectedDate!),
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDate == null ? _kGray : _kDark,
                    fontWeight: _selectedDate == null
                        ? FontWeight.w400
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Arrival window',
          style: TextStyle(fontSize: 13, color: _kGray),
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
                  color: sel ? _kRed.withValues(alpha: 0.07) : _kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? _kRed : _kBorder,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: sel ? _kRed : _kGray,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      opt,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? _kRed : _kDark,
                      ),
                    ),
                    if (sel) ...[
                      const Spacer(),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: _kRed,
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
          'Workers are notified immediately after booking.',
          color: _kRed,
        ),
      ],
    );
  }

  // ── D. Issue title ────────────────────────────────────────────────────────
  Widget _buildTitleSection() {
    return _sectionCard(
      title: "What's the issue",
      child: TextFormField(
        controller: _titleCtrl,
        textInputAction: TextInputAction.next,
        maxLength: 120,
        decoration: InputDecoration(
          hintText: 'e.g. AC not cooling, leaking faucet...',
          hintStyle: const TextStyle(color: _kGray, fontSize: 14),
          counterText: '',
          filled: true,
          fillColor: _kSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kGreen, width: 1.4),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  // ── E. Description (commented out — kept for future use) ─────────────────
  // Widget _buildDescriptionSection() {
  //   return _sectionCard(
  //     title: 'Description',
  //     child: TextFormField(
  //       controller: _descriptionCtrl,
  //       maxLines: 4,
  //       textInputAction: TextInputAction.done,
  //       decoration: InputDecoration(
  //         hintText: 'Describe the issue (optional)',
  //         hintStyle: const TextStyle(color: _kGray, fontSize: 14),
  //         filled: true,
  //         fillColor: _kSurface,
  //         border: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: const BorderSide(color: _kBorder),
  //         ),
  //         enabledBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: const BorderSide(color: _kBorder),
  //         ),
  //         focusedBorder: OutlineInputBorder(
  //           borderRadius: BorderRadius.circular(12),
  //           borderSide: const BorderSide(color: _kGreen, width: 1.4),
  //         ),
  //         contentPadding: const EdgeInsets.all(14),
  //       ),
  //     ),
  //   );
  // }

  // ── F. Location ───────────────────────────────────────────────────────────
  Widget _buildLocationSection() {
    return _sectionCard(
      title: 'Service Address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _addressCtrl,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'e.g. House 12, Street 5, DHA Phase 6, Karachi',
              hintStyle: const TextStyle(color: _kGray, fontSize: 14),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: _kGreen,
              ),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kGreen, width: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _locationLoading ? null : _captureCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: (_gpsLat != null && _pickedAddress == null)
                          ? _kGreen.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_gpsLat != null && _pickedAddress == null)
                            ? _kGreen.withValues(alpha: 0.4)
                            : _kBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _locationLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kGreen,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                (_gpsLat != null && _pickedAddress == null)
                                    ? Icons.gps_fixed_rounded
                                    : Icons.my_location_rounded,
                                size: 15,
                                color: _kGreen,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  (_gpsLat != null && _pickedAddress == null)
                                      ? 'GPS captured'
                                      : 'Use GPS',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: _kGreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _openMapPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: (_gpsLat != null && _pickedAddress != null)
                          ? _kGreen.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_gpsLat != null && _pickedAddress != null)
                            ? _kGreen.withValues(alpha: 0.4)
                            : _kBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (_gpsLat != null && _pickedAddress != null)
                              ? Icons.map_rounded
                              : Icons.map_outlined,
                          size: 15,
                          color: _kGreen,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            (_gpsLat != null && _pickedAddress != null)
                                ? 'Map picked'
                                : 'Pick on Map',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _kGreen,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_gpsLat != null && _gpsLng != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 13,
                  color: _kGreen,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _pickedAddress != null
                        ? 'Map: $_pickedAddress'
                        : 'GPS: ${_gpsLat!.toStringAsFixed(5)}, '
                              '${_gpsLng!.toStringAsFixed(5)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kGreen.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Location required — use GPS or pick on map.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
          ],
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

    return _sectionCard(
      title: 'Voice Note & Attachments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing voice note row (edit mode only)
          if (_existingVoiceNote != null && _voiceNotePath == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Voice note attached',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kDark,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeExistingVoiceNote,
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: _kGray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // WhatsApp-style voice bar
          _buildVoiceBar(),
          const SizedBox(height: 12),

          // Action row: file attachment + camera
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.attach_file_rounded,
                  label: 'Attach File',
                  onTap: canAddMore ? _pickAttachment : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
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
            '$_totalAttachmentCount/4  ·  jpg, png, mp4 (max ${_kMaxVideoSecs}s)',
            style: const TextStyle(fontSize: 11, color: _kGray),
          ),
          if (_removedAttachmentIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${_removedAttachmentIds.length} existing attachment(s) will be removed on save.',
              style: const TextStyle(fontSize: 11, color: _kRed),
            ),
          ],
        ],
      ),
    );
  }

  // WhatsApp-style voice note bar — 3 states: idle, recording, preview.
  Widget _buildVoiceBar() {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            // Trash
            _VoiceBarBtn(
              onTap: _cancelRecording,
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _kGray,
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
                  color: Colors.red.withValues(
                    alpha: 0.5 + _pulseCtrl.value * 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Timer
            Text(
              _fmtSeconds(_recordingSeconds),
              style: const TextStyle(
                fontSize: 12,
                color: _kGray,
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
              bg: _kGreen.withValues(alpha: 0.12),
              child: const Icon(Icons.pause_rounded, color: _kGreen, size: 20),
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
          color: _kSurface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic_none_rounded, size: 18, color: _kGray),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tap mic to record a voice note',
                style: TextStyle(fontSize: 13, color: _kGray),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, size: 16, color: _kGreen),
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
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? _kBorder : _kBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled ? _kGreen : _kGray,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled ? _kDark : _kGray,
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
              onRemove: () =>
                  setState(() => _newAttachments.removeAt(idx)),
            );
          }),
        ];

        return Wrap(spacing: 12, runSpacing: 12, children: tiles);
      },
    );
  }

  Widget _buildPreviewTile({
    required double w,
    required double h,
    required bool isVideo,
    String? localPath,
    String? networkUrl,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: isVideo
                    ? Container(
                        color: _kDark,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white54,
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
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kGreen,
                                  ),
                                ),
                              ),
                      )
                    : Container(color: _kSurface),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
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
      barrierColor: Colors.black87,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: isVideo
                  ? const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 80,
                      color: Colors.white38,
                    )
                  : localPath != null
                  ? InteractiveViewer(
                      child: Image.file(
                        File(localPath),
                        fit: BoxFit.contain,
                      ),
                    )
                  : networkUrl != null
                  ? InteractiveViewer(
                      child: Image.network(
                        networkUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── H. Live timing summary ────────────────────────────────────────────────
  Widget _buildLiveSummary() {
    final text = _computeLiveSummary();
    final isReady =
        _isUrgent || (_selectedDate != null && _selectedTimeSlot != null);
    final color = _isUrgent ? _kRed : _kGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReady ? color.withValues(alpha: 0.07) : _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReady ? color.withValues(alpha: 0.3) : _kBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 15,
            color: isReady ? color : _kGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isReady ? color : _kGray,
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
          backgroundColor: _kGreen,
          disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isEditMode ? 'Save Changes' : 'Book Service',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ── Step validation ──────────────────────────────────────────────────────────
  bool _validateStep1() {
    if (_selectedService == null) {
      _showError('Please select a service.');
      return false;
    }
    if (!_isUrgent) {
      if (_selectedDate == null) {
        _showError('Please select a date.');
        return false;
      }
      if (_selectedTimeSlot == null) {
        _showError('Please select an arrival window.');
        return false;
      }
    } else {
      if (_urgentOption == null) {
        _showError('Please select an urgency window.');
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep < 2) setState(() => _currentStep++);
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
    const labels = ['Schedule', 'Details', 'Address'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(3, (i) {
          final isDone = i < _currentStep;
          final isActive = i == _currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    decoration: BoxDecoration(
                      color: (isDone || isActive) ? _kGreen : _kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: (isDone || isActive) ? _kGreen : _kGray,
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

  // ── Step 1: Service + job type + schedule ─────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceSection(),
          const SizedBox(height: 16),
          _buildJobTypeToggle(),
          const SizedBox(height: 16),
          _buildSchedulingSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 2: Issue title + voice note + attachments ────────────────────────────
  Widget _buildStep2() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(),
          const SizedBox(height: 16),
          _buildMediaSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 3: Service address + submit ──────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationSection(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step navigation buttons ───────────────────────────────────────────────────
  Widget _buildStepNavButtons() {
    final isLast = _currentStep == 2;
    final isFirst = _currentStep == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  foregroundColor: _kGreen,
                  side: const BorderSide(color: _kGreen),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back',
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
                backgroundColor: _kGreen,
                disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isLast
                  ? (_isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Save Changes' : 'Book Service',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ))
                  : const Text(
                      'Next',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const stepTitles = ['Schedule', 'Details', 'Address'];

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _prevStep,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: _kDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode ? 'Edit Booking' : 'Book a Service',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                      Text(
                        'Step ${_currentStep + 1} of 3  ·  ${stepTitles[_currentStep]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Step indicator ────────────────────────────────────────────────────
            _buildStepIndicator(),
            const SizedBox(height: 12),

            // ── Step content ──────────────────────────────────────────────────────
            Expanded(
              child: switch (_currentStep) {
                0 => _buildStep1(),
                1 => _buildStep2(),
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
      bottomNavigationBar: const ClientBottomNavBar(currentIndex: 0),
    );
  }
}

// ── Voice bar helper widgets ──────────────────────────────────────────────────

class _VoiceBarBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color? bg;

  const _VoiceBarBtn({
    required this.onTap,
    required this.child,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg ?? Colors.transparent,
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
    4.0, 9.0, 15.0, 7.0, 19.0, 12.0, 6.0, 14.0,
    9.0, 5.0, 17.0, 11.0, 7.0, 13.0, 8.0, 10.0,
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
                      ? const EdgeInsets.only(right: 2)
                      : null,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.5 + 0.5 * (i.isEven ? animation.value : 1.0 - animation.value)),
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

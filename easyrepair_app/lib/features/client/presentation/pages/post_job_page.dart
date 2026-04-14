import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/errors/failures.dart';
import '../../../../features/bookings/domain/entities/booking_entity.dart';
import '../../../../features/bookings/domain/entities/create_booking_request.dart';
import '../../../../features/bookings/domain/entities/update_booking_request.dart';
import '../../../../features/bookings/presentation/providers/booking_providers.dart';
import '../../../../features/categories/presentation/providers/categories_providers.dart';
import '../widgets/client_bottom_nav_bar.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/service_card.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFFFF5F15);
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
  // Address label returned by the map picker (reverse-geocoded).
  // Only non-null when the user picked via map; GPS capture uses the typed address.
  String? _pickedAddress;
  bool _locationLoading = false;

  bool _isSubmitting = false;

  // ── New file attachments (locally picked, not yet uploaded) ─────────────────
  final _picker = ImagePicker();
  final List<XFile> _newAttachments = [];

  // ── Existing attachments from API (edit mode) ───────────────────────────────
  List<BookingAttachmentEntity> _existingAttachments = [];
  // IDs of existing attachments the user wants to remove on save.
  final Set<String> _removedAttachmentIds = {};

  // ── Voice note — new recording ───────────────────────────────────────────────
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _voiceNotePath; // path to newly recorded voice note
  StreamSubscription<PlayerState>? _playerStateSub;

  // ── Voice note — existing (edit mode) ────────────────────────────────────────
  BookingAttachmentEntity? _existingVoiceNote;

  // ── Recording pulse animation ─────────────────────────────────────────────
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Tracks whether category preselection has been applied.
  bool _preselectionApplied = false;
  ProviderSubscription<AsyncValue<dynamic>>? _categoriesSubscription;

  // ── Edit-mode prefill guard ───────────────────────────────────────────────
  // Set to true after the form has been prefilled exactly once.
  // Prevents repeated prefills if the provider fires multiple times.
  bool _prefillDone = false;

  bool get _isEditMode => widget.editBookingId != null;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedService = widget.preselectedService;

    _playerStateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });

    // In edit mode: explicitly read the detail provider once the frame is
    // built, then prefill exactly once using _prefillDone guard.
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Trigger the provider to load (reads current or fetches if not cached).
        final bookingAsync = ref.read(
          bookingDetailProvider(widget.editBookingId!),
        );
        bookingAsync.whenData((booking) {
          if (!_prefillDone) _prefillFromBooking(booking);
        });

        // Also listen for future emissions (e.g. loading → data transition).
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

    // Category preselection (create mode with a pre-selected service).
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
    _playerStateSub?.cancel();
    _categoriesSubscription?.close();
    _titleCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Edit prefill ─────────────────────────────────────────────────────────────
  void _prefillFromBooking(BookingEntity booking) {
    // Guard: run exactly once.
    _prefillDone = true;

    // Separate existing voice notes from image/video attachments.
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
      // In edit mode the stored address string goes into the street/address field.
      // Area, house, and landmark fields are left empty so the user can optionally
      // enrich them; the combined string will be re-built on save.
      _addressCtrl.text = booking.address ?? '';
      _descriptionCtrl.text = booking.description ?? '';
      _gpsLat = booking.latitude != 0 ? booking.latitude : null;
      _gpsLng = booking.longitude != 0 ? booking.longitude : null;

      if (booking.timeSlot != null) {
        _selectedTimeSlot = booking.timeSlot!.label;
      }

      // Load existing media/voice into edit-mode state.
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
    if (_isUrgent)
      return 'Job goes live immediately after you book the service.';
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
          if (mounted)
            _showError('Video must be $_kMaxVideoSecs seconds or shorter.');
          return;
        }
      }
    }
    if (file != null && mounted) setState(() => _newAttachments.add(file!));
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
      if (mounted) {
        setState(() {
          _gpsLat = pos.latitude;
          _gpsLng = pos.longitude;
          _pickedAddress = null; // GPS capture; use typed address field
        });
      }
    } catch (_) {
      if (mounted) _showError('Could not retrieve location. Please try again.');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // ── Map picker ────────────────────────────────────────────────────────────
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
        // Pre-fill address field if it's empty or was auto-filled by previous pick
        if (_addressCtrl.text.trim().isEmpty || _pickedAddress != null) {
          _addressCtrl.text = result.address;
        }
      });
    }
  }

  // ── Voice note logic ──────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _pulseCtrl.stop();
      setState(() {
        _isRecording = false;
        _voiceNotePath = path;
      });
    } else {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
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
      setState(() => _isRecording = true);
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.stop();
    } else {
      await _player.play(DeviceFileSource(_voiceNotePath!));
    }
  }

  Future<void> _deleteVoiceNote() async {
    await _player.stop();
    final file = File(_voiceNotePath!);
    if (await file.exists()) await file.delete();
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

    // Silently attempt GPS if coordinates are not yet captured.
    // Coordinates improve nearby-worker matching but are not required for booking.
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

    // Upload any attachments that were picked before submission.
    await _uploadNewAttachments(booking.id);
    // Upload new voice note if recorded.
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

    // Delete removed existing attachments.
    for (final id in _removedAttachmentIds) {
      final result = await ref
          .read(bookingRepositoryProvider)
          .deleteAttachment(widget.editBookingId!, id);
      result.fold((failure) => throw failure, (_) {});
    }

    // Upload newly added file attachments.
    await _uploadNewAttachments(widget.editBookingId!);

    // Upload new voice note (if recorded, replacing the old one already removed above).
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
    if (e is NetworkFailure)
      return 'No internet connection. Please check your network.';
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
        error: (_, __) => const SizedBox(
          height: 40,
          child: Center(
            child: Text(
              'Failed to load services. Please restart the app.',
              style: TextStyle(fontSize: 13, color: _kGray),
            ),
          ),
        ),
        data: (categories) {
          final rows = <Widget>[];
          for (var i = 0; i < categories.length; i += 2) {
            final left = categories[i];
            final right = i + 1 < categories.length ? categories[i + 1] : null;
            rows.add(
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ServiceCard(
                        title: left.name,
                        emoji: left.emoji,
                        backgroundColor: categoryBgColor(left.name),
                        emojiBackgroundColor: categoryEmojiBgColor(left.name),
                        isSelected: _selectedService == left.name,
                        onTap: () =>
                            setState(() => _selectedService = left.name),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: right != null
                          ? ServiceCard(
                              title: right.name,
                              emoji: right.emoji,
                              backgroundColor: categoryBgColor(right.name),
                              emojiBackgroundColor: categoryEmojiBgColor(
                                right.name,
                              ),
                              isSelected: _selectedService == right.name,
                              onTap: () =>
                                  setState(() => _selectedService = right.name),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(children: rows);
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

  // ── C. Scheduling ─────────────────────────────────────────────────────────
  Widget _buildSchedulingSection() {
    return _sectionCard(
      title: 'Schedule',
      child: _isUrgent ? _buildUrgentSchedule() : _buildNormalSchedule(),
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
        const SizedBox(height: 12),
        _infoNote(
          'Job goes live 1 hour before the scheduled time and notifies workers.',
          color: _kGreen,
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

  // ── Title field (shown in both modes) ─────────────────────────────────────
  Widget _buildTitleSection() {
    return _sectionCard(
      title: 'Issue Title',
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

  // ── D. Description ────────────────────────────────────────────────────────
  Widget _buildDescriptionSection() {
    return _sectionCard(
      title: 'Description',
      child: TextFormField(
        controller: _descriptionCtrl,
        maxLines: 4,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Describe the issue (optional)',
          hintStyle: const TextStyle(color: _kGray, fontSize: 14),
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

  // ── E. Location ───────────────────────────────────────────────────────────
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
              // ── Use Current Location ──────────────────────────────────────
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
              // ── Pick on Map ───────────────────────────────────────────────
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

  // ── F. Attachments ────────────────────────────────────────────────────────
  Widget _buildAttachmentsSection() {
    // Visible existing attachments (not yet removed)
    final visibleExisting = _existingAttachments
        .where((a) => !_removedAttachmentIds.contains(a.id))
        .toList();
    final canAddMore = _totalAttachmentCount < 4;

    return _sectionCard(
      title: 'Attachments (optional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing attachments (edit mode)
                ...visibleExisting.map((attachment) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        _ExistingAttachmentThumbnail(attachment: attachment),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _removedAttachmentIds.add(attachment.id);
                            }),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Newly picked files
                ..._newAttachments.asMap().entries.map((e) {
                  final idx = e.key;
                  final file = e.value;
                  final isVideo =
                      file.mimeType?.startsWith('video') == true ||
                      file.path.toLowerCase().endsWith('.mp4') ||
                      file.path.toLowerCase().endsWith('.mov');
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isVideo
                              ? Container(
                                  width: 90,
                                  height: 90,
                                  color: _kDark,
                                  child: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                )
                              : Image.file(
                                  File(file.path),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _newAttachments.removeAt(idx)),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Add button
                if (canAddMore)
                  GestureDetector(
                    onTap: _pickAttachment,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 24, color: _kGreen),
                          SizedBox(height: 4),
                          Text(
                            'Add',
                            style: TextStyle(fontSize: 11, color: _kGray),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  // ── G. Voice note ─────────────────────────────────────────────────────────
  Widget _buildVoiceNoteSection() {
    return _sectionCard(
      title: 'Voice Note (optional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show existing voice note in edit mode
          if (_existingVoiceNote != null && _voiceNotePath == null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice note attached',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kDark,
                          ),
                        ),
                        Text(
                          'Tap × to remove or record a new one to replace',
                          style: TextStyle(fontSize: 11, color: _kGray),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeExistingVoiceNote,
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: _kGray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _infoNote(
              'Record a new voice note to replace the existing one.',
              color: _kGreen,
            ),
            const SizedBox(height: 10),
          ],
          _buildVoiceNoteContent(),
        ],
      ),
    );
  }

  Widget _buildVoiceNoteContent() {
    if (_voiceNotePath != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlayback,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Voice note recorded  ·  m4a',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kDark,
                ),
              ),
            ),
            GestureDetector(
              onTap: _deleteVoiceNote,
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: _kGray,
              ),
            ),
          ],
        ),
      );
    }

    if (_isRecording) {
      return GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kRed),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) => Opacity(
                  opacity: _pulseCtrl.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _kRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recording… tap to stop',
                style: TextStyle(
                  fontSize: 14,
                  color: _kRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.stop_rounded, color: _kRed, size: 20),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_rounded, color: _kGreen, size: 20),
            SizedBox(width: 8),
            Text(
              'Tap to record',
              style: TextStyle(
                fontSize: 14,
                color: _kGreen,
                fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReady ? color.withValues(alpha: 0.07) : _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? color.withValues(alpha: 0.3) : _kBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: isReady ? color : _kGray,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isReady ? color : _kGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── I. Submit button ──────────────────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
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
                  Text(
                    _isEditMode ? 'Edit Booking' : 'Book a Service',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 80 + bottomPad + 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildServiceSection(),
                    const SizedBox(height: 16),
                    _buildJobTypeToggle(),
                    const SizedBox(height: 16),
                    _buildSchedulingSection(),
                    const SizedBox(height: 16),
                    _buildTitleSection(),
                    const SizedBox(height: 16),
                    _buildDescriptionSection(),
                    const SizedBox(height: 16),
                    _buildLocationSection(),
                    const SizedBox(height: 16),
                    _buildAttachmentsSection(),
                    const SizedBox(height: 16),
                    _buildVoiceNoteSection(),
                    const SizedBox(height: 16),
                    _buildLiveSummary(),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const ClientBottomNavBar(currentIndex: 0),
    );
  }
}

// ── Existing attachment thumbnail (network image / video card) ────────────────

class _ExistingAttachmentThumbnail extends StatelessWidget {
  final BookingAttachmentEntity attachment;

  const _ExistingAttachmentThumbnail({required this.attachment});

  @override
  Widget build(BuildContext context) {
    if (attachment.type == AttachmentType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          attachment.url,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF94A3B8),
            ),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kGreen,
                    ),
                  ),
                ),
        ),
      );
    }

    // Video thumbnail
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.play_circle_fill_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/places_service.dart';

class RideLocations {
  final LatLng pickup; final String pickupAddress;
  final LatLng dropoff; final String dropoffAddress;
  RideLocations({required this.pickup, required this.pickupAddress, required this.dropoff, required this.dropoffAddress});
}

class DestinationSheet extends ConsumerStatefulWidget {
  final LatLng initialPickup;
  final String initialPickupAddress;
  const DestinationSheet({super.key, required this.initialPickup, required this.initialPickupAddress});

  @override
  ConsumerState<DestinationSheet> createState() => _DestinationSheetState();
}

enum _ActiveField { pickup, dropoff }

class _DestinationSheetState extends ConsumerState<DestinationSheet> {
  late final TextEditingController _pickupCtrl;
  late final TextEditingController _dropoffCtrl;
  final _pickupFocus = FocusNode();
  final _dropoffFocus = FocusNode();

  LatLng? _pickup;
  LatLng? _dropoff;
  String? _pickupAddress;
  String? _dropoffAddress;

  _ActiveField _active = _ActiveField.dropoff;
  List<SavedPlace> _saved = [];
  bool _loadingSaved = true;

  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  String? _error;
  Timer? _debounce;
  int _queryId = 0;

  @override
  void initState() {
    super.initState();
    _pickup = widget.initialPickup;
    _pickupAddress = widget.initialPickupAddress;
    _pickupCtrl = TextEditingController(text: widget.initialPickupAddress);
    _dropoffCtrl = TextEditingController();

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) setState(() { _active = _ActiveField.pickup; _suggestions = []; });
    });
    _dropoffFocus.addListener(() {
      if (_dropoffFocus.hasFocus) setState(() { _active = _ActiveField.dropoff; _suggestions = []; });
    });

    _loadSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dropoffFocus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtrl.dispose(); _dropoffCtrl.dispose();
    _pickupFocus.dispose(); _dropoffFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final places = await ref.read(savedPlacesServiceProvider).list();
      if (mounted) setState(() { _saved = places; _loadingSaved = false; });
    } catch (_) { if (mounted) setState(() => _loadingSaved = false); }
  }

  TextEditingController get _activeCtrl => _active == _ActiveField.pickup ? _pickupCtrl : _dropoffCtrl;

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) { setState(() { _suggestions = []; _searching = false; _error = null; }); return; }
    _debounce = Timer(const Duration(milliseconds: 280), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final id = ++_queryId;
    setState(() { _searching = true; _error = null; });
    try {
      final res = await ref.read(placesServiceProvider).autocomplete(q);
      if (!mounted || id != _queryId) return;
      setState(() { _suggestions = res; _searching = false; });
    } catch (e) {
      if (!mounted || id != _queryId) return;
      setState(() { _error = e.toString(); _searching = false; _suggestions = []; });
    }
  }

  Future<void> _pickSuggestion(PlaceSuggestion s) async {
    setState(() => _searching = true);
    try {
      final d = await ref.read(placesServiceProvider).details(s.placeId);
      if (!mounted) return;
      _applyPick(LatLng(d.lat, d.lng), d.address);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _searching = false; });
    }
  }

  void _pickSaved(SavedPlace p) => _applyPick(LatLng(p.lat, p.lng), p.address);

  void _applyPick(LatLng point, String address) {
    setState(() {
      if (_active == _ActiveField.pickup) {
        _pickup = point; _pickupAddress = address; _pickupCtrl.text = address;
      } else {
        _dropoff = point; _dropoffAddress = address; _dropoffCtrl.text = address;
      }
      _suggestions = []; _searching = false;
    });
    // Move focus forward once
    if (_active == _ActiveField.pickup && _dropoff == null) {
      _dropoffFocus.requestFocus();
    } else if (_active == _ActiveField.dropoff && _pickup == null) {
      _pickupFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
    _maybeSubmit();
  }

  void _maybeSubmit() {
    if (_pickup != null && _dropoff != null) {
      // don't auto-pop — let user confirm via button so they can tweak either field.
    }
  }

  void _confirm() {
    if (_pickup == null || _dropoff == null) return;
    Navigator.pop(context, RideLocations(
      pickup: _pickup!, pickupAddress: _pickupAddress ?? 'Pickup',
      dropoff: _dropoff!, dropoffAddress: _dropoffAddress ?? 'Destination',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final showingSuggestions = _activeCtrl.text.trim().length >= 2;
    final canConfirm = _pickup != null && _dropoff != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.6, maxChildSize: 0.96, expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 14),
            // Inputs
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _FieldRow(
                      icon: Icons.radio_button_checked,
                      iconColor: AppColors.accent,
                      hint: 'Pickup location',
                      controller: _pickupCtrl,
                      focus: _pickupFocus,
                      active: _active == _ActiveField.pickup,
                      onChanged: _onQueryChanged,
                      onClear: () { _pickupCtrl.clear(); setState(() { _pickup = null; _pickupAddress = null; }); _onQueryChanged(''); },
                    ),
                    const Divider(height: 1, indent: 48),
                    _FieldRow(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.primary,
                      hint: 'Where to?',
                      controller: _dropoffCtrl,
                      focus: _dropoffFocus,
                      active: _active == _ActiveField.dropoff,
                      onChanged: _onQueryChanged,
                      onClear: () { _dropoffCtrl.clear(); setState(() { _dropoff = null; _dropoffAddress = null; }); _onQueryChanged(''); },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.zero,
                children: [
                  if (!showingSuggestions) ...[
                    if (_saved.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Text('Saved Places',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 13, letterSpacing: 0.3)),
                      ),
                      ..._saved.map((p) => _tile(
                            icon: _savedIcon(p.icon),
                            title: p.label, subtitle: p.address,
                            onTap: () => _pickSaved(p),
                          )),
                    ],
                    if (_loadingSaved)
                      const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                    if (!_loadingSaved && _saved.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Start typing to search', style: TextStyle(color: AppColors.textSecondary))),
                      ),
                  ] else ...[
                    if (_searching)
                      const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                    if (_error != null)
                      Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                    if (!_searching && _error == null && _suggestions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('No results', style: TextStyle(color: AppColors.textSecondary))),
                      ),
                    ..._suggestions.map((s) => _tile(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
                            child: const Icon(Icons.place_outlined, color: AppColors.primary, size: 18),
                          ),
                          title: s.mainText, subtitle: s.secondaryText,
                          onTap: () => _pickSuggestion(s),
                        )),
                  ],
                ],
              ),
            ),
            if (canConfirm)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile({required Widget icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: icon,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: (subtitle == null || subtitle.isEmpty)
          ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }

  Widget _savedIcon(String name) {
    IconData i = switch (name) {
      'home' => Icons.home_rounded,
      'work' => Icons.work_rounded,
      'fitness' => Icons.fitness_center_rounded,
      _ => Icons.place_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
      child: Icon(i, color: AppColors.primary, size: 18),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String hint;
  final TextEditingController controller;
  final FocusNode focus;
  final bool active;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _FieldRow({
    required this.icon, required this.iconColor, required this.hint,
    required this.controller, required this.focus, required this.active,
    required this.onChanged, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
              onPressed: onClear, splashRadius: 18,
            ),
        ],
      ),
    );
  }
}

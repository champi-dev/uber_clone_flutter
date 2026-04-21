import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/landmarks.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});
  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  List<SavedPlace> _places = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _places = await ref.read(savedPlacesServiceProvider).list();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit([SavedPlace? existing]) async {
    final result = await showModalBottomSheet<SavedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditSheet(existing: existing),
    );
    if (result != null) _load();
  }

  Future<void> _delete(SavedPlace p) async {
    try {
      await ref.read(savedPlacesServiceProvider).delete(p.id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Places')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
              ? const Center(child: Text('No saved places yet', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _places.length,
                  itemBuilder: (_, i) {
                    final p = _places[i];
                    return Dismissible(
                      key: Key(p.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppColors.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(p),
                      child: Card(
                        child: ListTile(
                          leading: _iconFor(p.icon),
                          title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _addOrEdit(p)),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add), label: const Text('Add Place'),
      ),
    );
  }

  Widget _iconFor(String name) {
    IconData i = switch (name) {
      'home' => Icons.home,
      'work' => Icons.work_outline,
      'fitness' => Icons.fitness_center,
      _ => Icons.place,
    };
    return CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: Icon(i, color: AppColors.primary));
  }
}

class _AddEditSheet extends ConsumerStatefulWidget {
  final SavedPlace? existing;
  const _AddEditSheet({this.existing});
  @override
  ConsumerState<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends ConsumerState<_AddEditSheet> {
  late final TextEditingController _label;
  late String _icon;
  Landmark? _selectedLandmark;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _icon = widget.existing?.icon ?? 'home';
    if (widget.existing != null) {
      _selectedLandmark = monteriaLandmarks.firstWhere(
        (l) => l.lat == widget.existing!.lat && l.lng == widget.existing!.lng,
        orElse: () => Landmark(widget.existing!.address, widget.existing!.lat, widget.existing!.lng, ''),
      );
    }
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty || _selectedLandmark == null) return;
    setState(() => _saving = true);
    try {
      final svc = ref.read(savedPlacesServiceProvider);
      final SavedPlace r;
      if (widget.existing == null) {
        r = await svc.create(
          label: _label.text.trim(), address: _selectedLandmark!.name,
          lat: _selectedLandmark!.lat, lng: _selectedLandmark!.lng, icon: _icon,
        );
      } else {
        r = await svc.update(widget.existing!.id, {
          'label': _label.text.trim(), 'address': _selectedLandmark!.name,
          'lat': _selectedLandmark!.lat, 'lng': _selectedLandmark!.lng, 'icon': _icon,
        });
      }
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.existing == null ? 'Add Place' : 'Edit Place',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'Label')),
            const SizedBox(height: 16),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: ['home', 'work', 'fitness', 'place'].map((n) {
                return ChoiceChip(
                  label: Text(n),
                  selected: _icon == n,
                  onSelected: (_) => setState(() => _icon = n),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Choose location', style: TextStyle(fontWeight: FontWeight.w600)),
            ...monteriaLandmarks.map((l) => RadioListTile<Landmark>(
                  value: l,
                  groupValue: _selectedLandmark,
                  title: Text(l.name),
                  subtitle: Text(l.category, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onChanged: (v) => setState(() => _selectedLandmark = v),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

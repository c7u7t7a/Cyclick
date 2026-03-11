import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class BikeParking {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int capacity;
  final bool isCovered;
  final bool isActive;

  const BikeParking({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    this.isCovered = false,
    this.isActive = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory BikeParking.fromJson(Map<String, dynamic> j) => BikeParking(
        id: j['id'] as String,
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        capacity: (j['capacity'] as num? ?? 0).toInt(),
        isCovered: j['is_covered'] as bool? ?? false,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'capacity': capacity,
        'is_covered': isCovered,
        'is_active': isActive,
      };
}

class ParkingNotifier extends StateNotifier<AsyncValue<List<BikeParking>>> {
  ParkingNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await Supabase.instance.client
          .from('bike_parkings')
          .select()
          .eq('is_active', true)
          .order('name');
      state = AsyncValue.data(
          (rows as List).map((r) => BikeParking.fromJson(r)).toList());
    } catch (_) {
      state = AsyncValue.data(_seedParkings);
    }
  }

  Future<void> addParking(BikeParking p) async {
    // Omit id — let Supabase generate a UUID via default uuid_generate_v4()
    final data = p.toJson()..remove('id');
    // Let any insert error propagate — the UI's try/catch will surface it.
    await Supabase.instance.client.from('bike_parkings').insert(data);
    await _loadFresh();
  }

  /// Like [load] but never falls back to seed data — used after insert/update
  /// so a successful write is always reflected in state.
  Future<void> _loadFresh() async {
    final rows = await Supabase.instance.client
        .from('bike_parkings')
        .select()
        .eq('is_active', true)
        .order('name');
    state = AsyncValue.data(
        (rows as List).map((r) => BikeParking.fromJson(r)).toList());
  }
}

final parkingProvider =
    StateNotifierProvider<ParkingNotifier, AsyncValue<List<BikeParking>>>(
        (_) => ParkingNotifier());

final _seedParkings = [
  const BikeParking(
      id: 'p-001',
      name: 'Parcul Floreasca',
      latitude: 44.4680,
      longitude: 26.0920,
      capacity: 20,
      isCovered: false),
  const BikeParking(
      id: 'p-002',
      name: 'Stație Metro Iancului',
      latitude: 44.4390,
      longitude: 26.1200,
      capacity: 15,
      isCovered: true),
  const BikeParking(
      id: 'p-003',
      name: 'Bd. Colentina nr. 41',
      latitude: 44.4580,
      longitude: 26.1400,
      capacity: 10,
      isCovered: false),
];

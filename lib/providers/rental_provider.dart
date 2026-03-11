import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class RentalStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int availableBikes;
  final int totalDocks;
  final bool isActive;

  const RentalStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.availableBikes,
    required this.totalDocks,
    this.isActive = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory RentalStation.fromJson(Map<String, dynamic> j) => RentalStation(
        id: j['id'] as String,
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        availableBikes: (j['available_bikes'] as num? ?? 0).toInt(),
        totalDocks: (j['total_docks'] as num? ?? 10).toInt(),
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'available_bikes': availableBikes,
        'total_docks': totalDocks,
        'is_active': isActive,
      };
}

class RentalNotifier extends StateNotifier<AsyncValue<List<RentalStation>>> {
  RentalNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await Supabase.instance.client
          .from('rental_stations')
          .select()
          .eq('is_active', true)
          .order('name');
      state = AsyncValue.data(
          (rows as List).map((r) => RentalStation.fromJson(r)).toList());
    } catch (_) {
      // Fallback to seed data so the UI works before the table is created
      state = AsyncValue.data(_seedStations);
    }
  }

  Future<void> addStation(RentalStation s) async {
    await Supabase.instance.client.from('rental_stations').insert(s.toJson());
    await load();
  }

  Future<void> updateAvailability(String id, int bikes) async {
    await Supabase.instance.client
        .from('rental_stations')
        .update({'available_bikes': bikes})
        .eq('id', id);
    await load();
  }
}

final rentalProvider =
    StateNotifierProvider<RentalNotifier, AsyncValue<List<RentalStation>>>(
        (_) => RentalNotifier());

// ─── Seed (shown until Supabase table exists) ─────────────────────────────────
final _seedStations = [
  const RentalStation(
    id: 'rs-001',
    name: 'Piața Obor',
    latitude: 44.4530,
    longitude: 26.0980,
    availableBikes: 5,
    totalDocks: 10,
  ),
  const RentalStation(
    id: 'rs-002',
    name: 'Parcul Tei',
    latitude: 44.4650,
    longitude: 26.1100,
    availableBikes: 3,
    totalDocks: 8,
  ),
  const RentalStation(
    id: 'rs-003',
    name: 'Bd. Ferdinand',
    latitude: 44.4440,
    longitude: 26.1050,
    availableBikes: 7,
    totalDocks: 12,
  ),
];

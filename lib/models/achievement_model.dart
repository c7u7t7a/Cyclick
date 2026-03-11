import 'package:flutter/material.dart';

/// Tier determines badge colour ring.
enum AchievementTier { bronze, silver, gold, platinum }

/// Logical category for filtering in the achievements screen.
enum AchievementCategory { riding, eco, social, safety, civic }

/// Snapshot of a user's stats used to evaluate achievement conditions.
class RideStats {
  final int rides;
  final double totalKm;
  final double totalCo2Grams;
  final int highRatedRides; // rides with safetyRating >= 4
  final int cityHallReports; // rides that submitted a city-hall message
  final bool hasJoinedGroup;
  final int friendCount;

  const RideStats({
    this.rides = 0,
    this.totalKm = 0,
    this.totalCo2Grams = 0,
    this.highRatedRides = 0,
    this.cityHallReports = 0,
    this.hasJoinedGroup = false,
    this.friendCount = 0,
  });
}

/// Static definition of a single achievement.
class AchievementDef {
  final String id;
  final String titleEn;
  final String titleRo;
  final String descEn;
  final String descRo;
  final String emoji;
  final AchievementTier tier;
  final AchievementCategory category;

  /// Returns true when [stats] satisfy this achievement's condition.
  final bool Function(RideStats stats) check;

  const AchievementDef({
    required this.id,
    required this.titleEn,
    required this.titleRo,
    required this.descEn,
    required this.descRo,
    required this.emoji,
    required this.tier,
    required this.category,
    required this.check,
  });

  String title(bool isRo) => isRo ? titleRo : titleEn;
  String desc(bool isRo) => isRo ? descRo : descEn;

  Color get tierColor {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFF9E9E9E);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.platinum:
        return const Color(0xFF29B6F6);
    }
  }

  String get tierLabel {
    switch (tier) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
    }
  }

  IconData get tierIcon {
    switch (tier) {
      case AchievementTier.bronze:
        return Icons.circle_outlined;
      case AchievementTier.silver:
        return Icons.star_border_rounded;
      case AchievementTier.gold:
        return Icons.star_rounded;
      case AchievementTier.platinum:
        return Icons.auto_awesome_rounded;
    }
  }
}

/// Row stored in `user_achievements`.
class UnlockedAchievement {
  final String achievementId;
  final DateTime unlockedAt;

  const UnlockedAchievement({
    required this.achievementId,
    required this.unlockedAt,
  });
}

// ─── Master list of all 16 achievements ──────────────────────────────────────

final List<AchievementDef> kAllAchievements = [
  // ── Riding: ride count ──────────────────────────────────────
  AchievementDef(
    id: 'first_ride',
    titleEn: 'First Pedal',
    titleRo: 'Prima Pedalare',
    descEn: 'Complete your first ride',
    descRo: 'Finalizează prima ta cursă',
    emoji: '🚴',
    tier: AchievementTier.bronze,
    category: AchievementCategory.riding,
    check: (s) => s.rides >= 1,
  ),
  AchievementDef(
    id: 'five_rides',
    titleEn: 'High Five',
    titleRo: 'Cinci Curse',
    descEn: 'Complete 5 rides',
    descRo: 'Finalizează 5 curse',
    emoji: '🤙',
    tier: AchievementTier.bronze,
    category: AchievementCategory.riding,
    check: (s) => s.rides >= 5,
  ),
  AchievementDef(
    id: 'ten_rides',
    titleEn: 'Perfect Ten',
    titleRo: 'Zece la Rând',
    descEn: 'Complete 10 rides',
    descRo: 'Finalizează 10 curse',
    emoji: '💪',
    tier: AchievementTier.silver,
    category: AchievementCategory.riding,
    check: (s) => s.rides >= 10,
  ),
  AchievementDef(
    id: 'twenty_five_rides',
    titleEn: 'Velodrome',
    titleRo: 'Velodrom',
    descEn: 'Complete 25 rides',
    descRo: 'Finalizează 25 de curse',
    emoji: '⭐',
    tier: AchievementTier.silver,
    category: AchievementCategory.riding,
    check: (s) => s.rides >= 25,
  ),
  AchievementDef(
    id: 'century_rides',
    titleEn: 'Century Club',
    titleRo: 'Centurion',
    descEn: 'Complete 100 rides',
    descRo: 'Finalizează 100 de curse',
    emoji: '🏆',
    tier: AchievementTier.gold,
    category: AchievementCategory.riding,
    check: (s) => s.rides >= 100,
  ),

  // ── Riding: distance ────────────────────────────────────────
  AchievementDef(
    id: 'ten_km',
    titleEn: '10 km Wanderer',
    titleRo: '10 km Explorator',
    descEn: 'Cycle a total of 10 km',
    descRo: 'Pedalează 10 km total',
    emoji: '📍',
    tier: AchievementTier.bronze,
    category: AchievementCategory.riding,
    check: (s) => s.totalKm >= 10,
  ),
  AchievementDef(
    id: 'fifty_km',
    titleEn: '50 km Explorer',
    titleRo: '50 km Explorator',
    descEn: 'Cycle a total of 50 km',
    descRo: 'Pedalează 50 km total',
    emoji: '🗺️',
    tier: AchievementTier.silver,
    category: AchievementCategory.riding,
    check: (s) => s.totalKm >= 50,
  ),
  AchievementDef(
    id: 'hundred_km',
    titleEn: 'Century Rider',
    titleRo: 'Ciclist de Secol',
    descEn: 'Cycle a total of 100 km',
    descRo: 'Pedalează 100 km total',
    emoji: '🚀',
    tier: AchievementTier.gold,
    category: AchievementCategory.riding,
    check: (s) => s.totalKm >= 100,
  ),
  AchievementDef(
    id: 'five_hundred_km',
    titleEn: 'Iron Cyclist',
    titleRo: 'Ciclist de Fier',
    descEn: 'Cycle a total of 500 km',
    descRo: 'Pedalează 500 km total',
    emoji: '🏅',
    tier: AchievementTier.platinum,
    category: AchievementCategory.riding,
    check: (s) => s.totalKm >= 500,
  ),

  // ── Eco ──────────────────────────────────────────────────────
  AchievementDef(
    id: 'eco_starter',
    titleEn: 'Eco Starter',
    titleRo: 'Eco-Inceput',
    descEn: 'Save 500 g of CO₂',
    descRo: 'Economisește 500 g de CO₂',
    emoji: '🌱',
    tier: AchievementTier.bronze,
    category: AchievementCategory.eco,
    check: (s) => s.totalCo2Grams >= 500,
  ),
  AchievementDef(
    id: 'eco_warrior',
    titleEn: 'Eco Warrior',
    titleRo: 'Luptător Eco',
    descEn: 'Save 1 kg of CO₂',
    descRo: 'Economisește 1 kg de CO₂',
    emoji: '🌿',
    tier: AchievementTier.silver,
    category: AchievementCategory.eco,
    check: (s) => s.totalCo2Grams >= 1000,
  ),
  AchievementDef(
    id: 'eco_hero',
    titleEn: 'Green Hero',
    titleRo: 'Erou Verde',
    descEn: 'Save 5 kg of CO₂',
    descRo: 'Economisește 5 kg de CO₂',
    emoji: '🌍',
    tier: AchievementTier.gold,
    category: AchievementCategory.eco,
    check: (s) => s.totalCo2Grams >= 5000,
  ),

  // ── Safety ───────────────────────────────────────────────────
  AchievementDef(
    id: 'safety_star',
    titleEn: 'Safety Star',
    titleRo: 'Steaua Siguranței',
    descEn: 'Rate 5 rides with 4+ stars',
    descRo: 'Evaluează 5 curse cu 4+ stele',
    emoji: '⛑️',
    tier: AchievementTier.silver,
    category: AchievementCategory.safety,
    check: (s) => s.highRatedRides >= 5,
  ),

  // ── Social ───────────────────────────────────────────────────
  AchievementDef(
    id: 'first_friend',
    titleEn: 'Social Cyclist',
    titleRo: 'Ciclist Social',
    descEn: 'Add your first friend',
    descRo: 'Adaugă primul prieten',
    emoji: '🤝',
    tier: AchievementTier.bronze,
    category: AchievementCategory.social,
    check: (s) => s.friendCount >= 1,
  ),
  AchievementDef(
    id: 'community_joiner',
    titleEn: 'Community Spirit',
    titleRo: 'Spirit Comunitar',
    descEn: 'Join a community group',
    descRo: 'Alătură-te unui grup comunitar',
    emoji: '👥',
    tier: AchievementTier.bronze,
    category: AchievementCategory.social,
    check: (s) => s.hasJoinedGroup,
  ),

  // ── Civic ────────────────────────────────────────────────────
  AchievementDef(
    id: 'civic_voice',
    titleEn: 'Civic Voice',
    titleRo: 'Voce Civică',
    descEn: 'Submit 3 city hall reports',
    descRo: 'Trimite 3 sesizări la primărie',
    emoji: '📢',
    tier: AchievementTier.bronze,
    category: AchievementCategory.civic,
    check: (s) => s.cityHallReports >= 3,
  ),
];

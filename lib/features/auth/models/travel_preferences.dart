import 'package:smart_travel_planner/features/itinerary/models/trip_preferences.dart';

enum BudgetTier {
  budget('Low'),
  standard('Medium'),
  luxury('High');

  const BudgetTier(this.plannerValue);
  final String plannerValue;
}

class TravelPreferences {
  const TravelPreferences({
    this.pace = PaceCategory.balanced,
    this.budget = BudgetTier.standard,
    this.diet = DietaryPreference.unrestricted,
  });

  final PaceCategory pace;
  final BudgetTier budget;
  final DietaryPreference diet;

  factory TravelPreferences.fromJson(Object? json) {
    final data = json is Map ? json : const {};
    return TravelPreferences(
      pace: switch (data['travel_pace']) {
        'relaxed' => PaceCategory.relaxed,
        'fast_paced' => PaceCategory.packed,
        _ => PaceCategory.balanced,
      },
      budget: switch (data['budget_tier']) {
        'budget' => BudgetTier.budget,
        'luxury' => BudgetTier.luxury,
        _ => BudgetTier.standard,
      },
      diet: switch (data['dietary_requirement']) {
        'halal_certified' => DietaryPreference.halalFriendly,
        'vegetarian' => DietaryPreference.vegetarian,
        _ => DietaryPreference.unrestricted,
      },
    );
  }

  Map<String, String> toJson() => {
    'travel_pace': switch (pace) {
      PaceCategory.relaxed => 'relaxed',
      PaceCategory.balanced => 'moderate',
      PaceCategory.packed => 'fast_paced',
    },
    'budget_tier': budget.name,
    'dietary_requirement': switch (diet) {
      DietaryPreference.halalFriendly => 'halal_certified',
      DietaryPreference.vegetarian => 'vegetarian',
      _ => 'none',
    },
  };
}

import 'package:flutter/material.dart';

/// One selectable habit icon.
class HabitIconDef {
  const HabitIconDef(this.key, this.label, this.icon, this.group);

  /// Stable identifier stored in the database. Never rename a key.
  final String key;
  final String label;
  final IconData icon;
  final String group;
}

const String kIconFitness = 'Fitness & sports';
const String kIconHealth = 'Health & care';
const String kIconMind = 'Mind & sleep';
const String kIconFood = 'Food & drink';
const String kIconHome = 'Home & chores';
const String kIconWork = 'Work & study';
const String kIconMoney = 'Money';
const String kIconSocial = 'Social';
const String kIconNature = 'Nature & travel';

const List<String> kIconGroups = <String>[
  kIconFitness,
  kIconHealth,
  kIconMind,
  kIconFood,
  kIconHome,
  kIconWork,
  kIconMoney,
  kIconSocial,
  kIconNature,
];

const List<HabitIconDef> kHabitIcons = <HabitIconDef>[
  // Fitness & sports
  HabitIconDef('fitness_center', 'Gym', Icons.fitness_center, kIconFitness),
  HabitIconDef('directions_run', 'Run', Icons.directions_run, kIconFitness),
  HabitIconDef('directions_walk', 'Walk', Icons.directions_walk, kIconFitness),
  HabitIconDef('directions_bike', 'Cycle', Icons.directions_bike, kIconFitness),
  HabitIconDef('pool', 'Swim', Icons.pool, kIconFitness),
  HabitIconDef('hiking', 'Hike', Icons.hiking, kIconFitness),
  HabitIconDef('self_improvement', 'Yoga', Icons.self_improvement, kIconFitness),
  HabitIconDef('sports_martial_arts', 'Martial arts', Icons.sports_martial_arts, kIconFitness),
  HabitIconDef('sports_gymnastics', 'Gymnastics', Icons.sports_gymnastics, kIconFitness),
  HabitIconDef('sports_soccer', 'Football', Icons.sports_soccer, kIconFitness),
  HabitIconDef('sports_basketball', 'Basketball', Icons.sports_basketball, kIconFitness),
  HabitIconDef('sports_tennis', 'Tennis', Icons.sports_tennis, kIconFitness),
  HabitIconDef('sports_golf', 'Golf', Icons.sports_golf, kIconFitness),
  HabitIconDef('sports_cricket', 'Cricket', Icons.sports_cricket, kIconFitness),
  HabitIconDef('sports_volleyball', 'Volleyball', Icons.sports_volleyball, kIconFitness),
  HabitIconDef('sports_baseball', 'Baseball', Icons.sports_baseball, kIconFitness),
  HabitIconDef('sports_handball', 'Handball', Icons.sports_handball, kIconFitness),
  HabitIconDef('sports_mma', 'Boxing', Icons.sports_mma, kIconFitness),
  HabitIconDef('rowing', 'Rowing', Icons.rowing, kIconFitness),
  HabitIconDef('kayaking', 'Kayaking', Icons.kayaking, kIconFitness),
  HabitIconDef('surfing', 'Surfing', Icons.surfing, kIconFitness),
  HabitIconDef('skateboarding', 'Skateboard', Icons.skateboarding, kIconFitness),
  HabitIconDef('ice_skating', 'Ice skating', Icons.ice_skating, kIconFitness),
  HabitIconDef('downhill_skiing', 'Skiing', Icons.downhill_skiing, kIconFitness),
  HabitIconDef('snowboarding', 'Snowboarding', Icons.snowboarding, kIconFitness),
  HabitIconDef('timer', 'Timer', Icons.timer, kIconFitness),
  // Health & care
  HabitIconDef('medical_services', 'Medical kit', Icons.medical_services, kIconHealth),
  HabitIconDef('favorite', 'Heart', Icons.favorite, kIconHealth),
  HabitIconDef('monitor_heart', 'Heart rate', Icons.monitor_heart, kIconHealth),
  HabitIconDef('medication', 'Medication', Icons.medication, kIconHealth),
  HabitIconDef('vaccines', 'Vaccine', Icons.vaccines, kIconHealth),
  HabitIconDef('healing', 'Healing', Icons.healing, kIconHealth),
  HabitIconDef('health_and_safety', 'Health', Icons.health_and_safety, kIconHealth),
  HabitIconDef('local_hospital', 'Hospital', Icons.local_hospital, kIconHealth),
  HabitIconDef('clean_hands', 'Wash hands', Icons.clean_hands, kIconHealth),
  HabitIconDef('sanitizer', 'Sanitizer', Icons.sanitizer, kIconHealth),
  HabitIconDef('masks', 'Mask', Icons.masks, kIconHealth),
  HabitIconDef('spa', 'Self care', Icons.spa, kIconHealth),
  HabitIconDef('smoke_free', 'No smoking', Icons.smoke_free, kIconHealth),
  HabitIconDef('no_drinks', 'No drinks', Icons.no_drinks, kIconHealth),
  // Mind & sleep
  HabitIconDef('bedtime', 'Sleep', Icons.bedtime, kIconMind),
  HabitIconDef('nightlight', 'Night', Icons.nightlight, kIconMind),
  HabitIconDef('alarm', 'Wake up', Icons.alarm, kIconMind),
  HabitIconDef('light_mode', 'Morning', Icons.light_mode, kIconMind),
  HabitIconDef('dark_mode', 'Evening', Icons.dark_mode, kIconMind),
  HabitIconDef('psychology', 'Mind', Icons.psychology, kIconMind),
  HabitIconDef('lightbulb', 'Ideas', Icons.lightbulb, kIconMind),
  HabitIconDef('menu_book', 'Read', Icons.menu_book, kIconMind),
  HabitIconDef('auto_stories', 'Stories', Icons.auto_stories, kIconMind),
  HabitIconDef('edit_note', 'Journal', Icons.edit_note, kIconMind),
  HabitIconDef('music_note', 'Music', Icons.music_note, kIconMind),
  HabitIconDef('headphones', 'Listen', Icons.headphones, kIconMind),
  HabitIconDef('brush', 'Paint', Icons.brush, kIconMind),
  HabitIconDef('palette', 'Art', Icons.palette, kIconMind),
  HabitIconDef('sports_esports', 'Gaming', Icons.sports_esports, kIconMind),
  // Food & drink
  HabitIconDef('water_drop', 'Water', Icons.water_drop, kIconFood),
  HabitIconDef('local_drink', 'Drink', Icons.local_drink, kIconFood),
  HabitIconDef('local_cafe', 'Coffee', Icons.local_cafe, kIconFood),
  HabitIconDef('restaurant', 'Meal', Icons.restaurant, kIconFood),
  HabitIconDef('lunch_dining', 'Lunch', Icons.lunch_dining, kIconFood),
  HabitIconDef('egg_alt', 'Breakfast', Icons.egg_alt, kIconFood),
  HabitIconDef('set_meal', 'Fish', Icons.set_meal, kIconFood),
  HabitIconDef('eco', 'Greens', Icons.eco, kIconFood),
  HabitIconDef('bakery_dining', 'Bakery', Icons.bakery_dining, kIconFood),
  HabitIconDef('icecream', 'Dessert', Icons.icecream, kIconFood),
  HabitIconDef('no_food', 'No snacks', Icons.no_food, kIconFood),
  HabitIconDef('wine_bar', 'Wine', Icons.wine_bar, kIconFood),
  HabitIconDef('sports_bar', 'Beer', Icons.sports_bar, kIconFood),
  // Home & chores
  HabitIconDef('home', 'Home', Icons.home, kIconHome),
  HabitIconDef('cleaning_services', 'Cleaning', Icons.cleaning_services, kIconHome),
  HabitIconDef('local_laundry_service', 'Laundry', Icons.local_laundry_service, kIconHome),
  HabitIconDef('kitchen', 'Kitchen', Icons.kitchen, kIconHome),
  HabitIconDef('bed', 'Make bed', Icons.bed, kIconHome),
  HabitIconDef('chair', 'Tidy', Icons.chair, kIconHome),
  HabitIconDef('yard', 'Garden', Icons.yard, kIconHome),
  HabitIconDef('pets', 'Pets', Icons.pets, kIconHome),
  HabitIconDef('recycling', 'Recycle', Icons.recycling, kIconHome),
  HabitIconDef('delete', 'Take out trash', Icons.delete, kIconHome),
  HabitIconDef('shopping_cart', 'Shopping', Icons.shopping_cart, kIconHome),
  HabitIconDef('handyman', 'Repairs', Icons.handyman, kIconHome),
  // Work & study
  HabitIconDef('work', 'Work', Icons.work, kIconWork),
  HabitIconDef('laptop', 'Laptop', Icons.laptop, kIconWork),
  HabitIconDef('code', 'Code', Icons.code, kIconWork),
  HabitIconDef('school', 'Study', Icons.school, kIconWork),
  HabitIconDef('edit', 'Write', Icons.edit, kIconWork),
  HabitIconDef('assignment', 'Assignment', Icons.assignment, kIconWork),
  HabitIconDef('checklist', 'Checklist', Icons.checklist, kIconWork),
  HabitIconDef('task_alt', 'Task', Icons.task_alt, kIconWork),
  HabitIconDef('event', 'Event', Icons.event, kIconWork),
  HabitIconDef('schedule', 'Schedule', Icons.schedule, kIconWork),
  HabitIconDef('mail', 'Email', Icons.mail, kIconWork),
  HabitIconDef('call', 'Call', Icons.call, kIconWork),
  HabitIconDef('translate', 'Language', Icons.translate, kIconWork),
  // Money
  HabitIconDef('savings', 'Savings', Icons.savings, kIconMoney),
  HabitIconDef('attach_money', 'Money', Icons.attach_money, kIconMoney),
  HabitIconDef('account_balance_wallet', 'Wallet', Icons.account_balance_wallet, kIconMoney),
  HabitIconDef('credit_card', 'Card', Icons.credit_card, kIconMoney),
  HabitIconDef('trending_up', 'Invest', Icons.trending_up, kIconMoney),
  HabitIconDef('receipt_long', 'Budget', Icons.receipt_long, kIconMoney),
  // Social
  HabitIconDef('people', 'Friends', Icons.people, kIconSocial),
  HabitIconDef('family_restroom', 'Family', Icons.family_restroom, kIconSocial),
  HabitIconDef('volunteer_activism', 'Give', Icons.volunteer_activism, kIconSocial),
  HabitIconDef('chat', 'Chat', Icons.chat, kIconSocial),
  HabitIconDef('celebration', 'Celebrate', Icons.celebration, kIconSocial),
  HabitIconDef('favorite_border', 'Love', Icons.favorite_border, kIconSocial),
  HabitIconDef('handshake', 'Network', Icons.handshake, kIconSocial),
  // Nature & travel
  HabitIconDef('park', 'Park', Icons.park, kIconNature),
  HabitIconDef('forest', 'Forest', Icons.forest, kIconNature),
  HabitIconDef('wb_sunny', 'Sun', Icons.wb_sunny, kIconNature),
  HabitIconDef('beach_access', 'Beach', Icons.beach_access, kIconNature),
  HabitIconDef('landscape', 'Landscape', Icons.landscape, kIconNature),
  HabitIconDef('explore', 'Explore', Icons.explore, kIconNature),
  HabitIconDef('flight', 'Travel', Icons.flight, kIconNature),
  HabitIconDef('directions_car', 'Drive', Icons.directions_car, kIconNature),
  HabitIconDef('directions_boat', 'Boat', Icons.directions_boat, kIconNature),
  HabitIconDef('train', 'Train', Icons.train, kIconNature),
];

/// Icon for a stored key; unknown keys fall back to the default icon.
IconData iconForKey(String key) {
  for (final HabitIconDef d in kHabitIcons) {
    if (d.key == key) return d.icon;
  }
  return Icons.medical_services;
}

/// Icons matching [query] (name, key or group) in [group] (null = all).
List<HabitIconDef> searchIcons(String query, {String? group}) {
  final String q = query.trim().toLowerCase();
  return kHabitIcons.where((HabitIconDef d) {
    if (group != null && d.group != group) return false;
    if (q.isEmpty) return true;
    return d.label.toLowerCase().contains(q) ||
        d.key.toLowerCase().contains(q) ||
        d.group.toLowerCase().contains(q);
  }).toList();
}

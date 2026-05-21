class UserSettings {
  final bool salesAlerts;
  final bool newArrivals;
  final bool deliveryUpdates;
  final bool pushEnabled;
  final bool darkMode;
  final String language;

  const UserSettings({
    this.salesAlerts = true,
    this.newArrivals = true,
    this.deliveryUpdates = true,
    this.pushEnabled = true,
    this.darkMode = false,
    this.language = 'English',
  });

  Map<String, dynamic> toMap() {
    return {
      'salesAlerts': salesAlerts,
      'newArrivals': newArrivals,
      'deliveryUpdates': deliveryUpdates,
      'pushEnabled': pushEnabled,
      'darkMode': darkMode,
      'language': language,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      salesAlerts: map['salesAlerts'] ?? true,
      newArrivals: map['newArrivals'] ?? true,
      deliveryUpdates: map['deliveryUpdates'] ?? true,
      pushEnabled: map['pushEnabled'] ?? true,
      darkMode: map['darkMode'] ?? false,
      language: map['language'] ?? 'English',
    );
  }

  UserSettings copyWith({
    bool? salesAlerts,
    bool? newArrivals,
    bool? deliveryUpdates,
    bool? pushEnabled,
    bool? darkMode,
    String? language,
  }) {
    return UserSettings(
      salesAlerts: salesAlerts ?? this.salesAlerts,
      newArrivals: newArrivals ?? this.newArrivals,
      deliveryUpdates: deliveryUpdates ?? this.deliveryUpdates,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }
}

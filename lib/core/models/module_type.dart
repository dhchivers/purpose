/// Enum representing the major modules in the Purpose app
enum ModuleType {
  purpose('purpose', 'Purpose'),
  vision('vision', 'Vision'),
  mission('mission', 'Mission'),
  goals('goals', 'Goals'),
  objectives('objectives', 'Objectives');

  final String value;
  final String displayName;

  const ModuleType(this.value, this.displayName);

  /// Convert from string to ModuleType
  static ModuleType fromString(String value) {
    return ModuleType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Invalid module type: $value'),
    );
  }
}

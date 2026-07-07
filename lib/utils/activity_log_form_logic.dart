class ActivityLogFormState {
  static String resolveType({
    required bool hasExistingLogs,
    required String currentType,
  }) {
    final normalizedCurrentType = currentType.trim().toLowerCase();
    if (hasExistingLogs) {
      if (normalizedCurrentType == 'new call') {
        return 'Follow Up Call';
      }
      return currentType;
    }

    return normalizedCurrentType == 'follow up call' ? 'Follow Up Call' : 'New Call';
  }

  static bool shouldShowTypeSelector({required bool hasExistingLogs}) => !hasExistingLogs;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dissuplain_app_web_mobile/utils/activity_log_form_logic.dart';

void main() {
  group('activity log form logic', () {
    test('keeps New Call before the first log and switches after logs exist', () {
      expect(
        ActivityLogFormState.resolveType(
          hasExistingLogs: false,
          currentType: 'New Call',
        ),
        'New Call',
      );

      expect(
        ActivityLogFormState.resolveType(
          hasExistingLogs: true,
          currentType: 'New Call',
        ),
        'Follow Up Call',
      );
    });

    test('hides the type selector once a log already exists', () {
      expect(
        ActivityLogFormState.shouldShowTypeSelector(hasExistingLogs: false),
        isTrue,
      );
      expect(
        ActivityLogFormState.shouldShowTypeSelector(hasExistingLogs: true),
        isFalse,
      );
    });
  });
}

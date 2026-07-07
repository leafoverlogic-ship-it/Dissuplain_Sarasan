import 'package:dissuplain_app_web_mobile/utils/client_detail_field_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('client detail field resolution', () {
    test('normalizes visit frequency values to nearest multiple of seven', () {
      expect(normalizeVisitFrequencyValue('15 Days'), '14');
      expect(normalizeVisitFrequencyValue('7 days'), '7');
      expect(normalizeVisitFrequencyValue('21'), '21');
      expect(normalizeVisitFrequencyValue('30 Days'), '28');
      expect(normalizeVisitFrequencyValue(''), '');
    });

    test('prefers new client fields and falls back to legacy values', () {
      final map = <String, dynamic>{
        'ClientName': 'Modern Clinic',
        'Institution_OR_Clinic_Name': 'Legacy Clinic',
        'Pharmacy_Name': 'Legacy Pharmacy',
        'Address1': '',
        'Institution_OR_Clinic_Address_1': 'Legacy Address 1',
        'Pharmacy_Address_1': 'Legacy Pharmacy Address',
        'Contact_Person_1_Name': 'Mr. Rao',
        'Doc_Name': 'Dr. Singh',
        'Pharmacy_Person_Name': 'Mr. Sharma',
      };

      expect(
        resolveClientDetailValue(map, ['ClientName', 'Institution_OR_Clinic_Name', 'Pharmacy_Name']),
        'Modern Clinic',
      );
      expect(
        resolveClientDetailValue(map, ['Address1', 'Institution_OR_Clinic_Address_1', 'Pharmacy_Address_1']),
        'Legacy Address 1',
      );
      expect(
        resolveClientDetailValue(map, ['Contact_Person_1_Name', 'Doc_Name', 'Pharmacy_Person_Name']),
        'Mr. Rao',
      );
    });
  });
}

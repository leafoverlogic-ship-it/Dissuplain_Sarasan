// lib/dataLayer/customers_repository.dart
import 'package:firebase_database/firebase_database.dart';

String _s(dynamic v) => v?.toString().trim() ?? '';

/// One row from /Clients
class CustomerEntry {
  // Required location IDs
  final String regionId;    // regionID
  final String areaId;      // areaID
  final String subareaId;   // subareaID

  // Identifiers
  final String? customerId;   // Customer_ID
  final String? customerCode; // customerCode

  // Names / Category
  final String? salesPersonName;   // Sales_Person / Sales_Person_ / SalesPersonName
  final String? category;          // Category
  final String? typeOfInstitution; // Type_of_Institution / TypeOfInstitution

  // Institution / Clinic
  final String? instituteOrClinicName;       // Institution_OR_Clinic_Name
  final String? instituteOrClinicAddress1;   // Institution_OR_Clinic_Address_1
  final String? instituteOrClinicAddress2;   // Institution_OR_Clinic_Address_2
  final String? instituteOrClinicLandmark;   // Institution_OR_Clinic_Landmark
  final String? instituteOrClinicPinCode;    // Institution_OR_Clinic_Pin_Code

  // Doctor
  final String? docName;        // Doc_Name
  final String? docMobileNo1;   // Doc_Mobile_No_1
  final String? docMobileNo2;   // Doc_Mobile_No_2

  // Pharmacy
  final String? pharmacyName;        // Pharmacy_Name
  final String? pharmacyAddress1;    // Pharmacy_Address_1
  final String? pharmacyAddress2;    // Pharmacy_Address_2
  final String? pharmacyLandmark;    // Pharmacy_Landmark
  final String? pharmacyPinCode;     // Pharmacy_Pin_Code
  final String? pharmacyPersonName;  // Pharmacy_Person_Name
  final String? pharmacyMobileNo1;   // Pharmacy_Mobile_No_1
  final String? pharmacyMobileNo2;   // Pharmacy_Mobile_No_2

  // Business / Status
  final String? gstNumber;             // GST_Number
  final String? status;                // Status
  final String? visitDays;             // Visit_Days
  final String? businessSlab;          // BUSINESS_SLAB
  final String? businessCat;           // BUSINESS_CAT
  final String? visitFrequencyInDays;  // VISIT_FREQUENCY_In_Days

  // Dates (string or epoch supported)
  final dynamic followupDate;     // followupDate (epoch ms or string)
  final String? dateOfFirstCall;  // Date_of_1st_Call / DateOfFirstCall
  final String? openingMonth;     // Opening_Month / OpeningMonth (yyyy-mm)
  final String? dateOfOpening;    // Date_of_Opening / DateOfOpening

  const CustomerEntry({
    required this.regionId,
    required this.areaId,
    required this.subareaId,
    this.customerId,
    this.customerCode,
    this.salesPersonName,
    this.category,
    this.typeOfInstitution,
    this.instituteOrClinicName,
    this.instituteOrClinicAddress1,
    this.instituteOrClinicAddress2,
    this.instituteOrClinicLandmark,
    this.instituteOrClinicPinCode,
    this.docName,
    this.docMobileNo1,
    this.docMobileNo2,
    this.pharmacyName,
    this.pharmacyAddress1,
    this.pharmacyAddress2,
    this.pharmacyLandmark,
    this.pharmacyPinCode,
    this.pharmacyPersonName,
    this.pharmacyMobileNo1,
    this.pharmacyMobileNo2,
    this.gstNumber,
    this.status,
    this.visitDays,
    this.businessSlab,
    this.businessCat,
    this.visitFrequencyInDays,
    this.followupDate,
    this.dateOfFirstCall,
    this.openingMonth,
    this.dateOfOpening,
  });

  factory CustomerEntry.fromMap(Map raw) {
    String s(String k) => _s(raw[k]);
    String? n(String k) {
      final v = _s(raw[k]);
      return v.isEmpty ? null : v;
    }

    // Handle weird migration keys / variants
    String? _salesPerson() =>
        n('Sales_Person') ?? n('SalesPersonName') ?? n('Sales_Person ');

    return CustomerEntry(
      regionId: _s(raw['regionID']),
      areaId: _s(raw['areaID']),
      subareaId: _s(raw['subareaID']),

      customerId: n('Customer_ID'),
      customerCode: n('customerCode'),

      salesPersonName: _salesPerson(),
      category: n('Category'),
      typeOfInstitution: n('Type_of_Institution') ?? n('TypeOfInstitution'),

      // Institution / Clinic
      instituteOrClinicName:       n('Institution_OR_Clinic_Name'),
      instituteOrClinicAddress1:   n('Institution_OR_Clinic_Address_1'),
      instituteOrClinicAddress2:   n('Institution_OR_Clinic_Address_2'),
      instituteOrClinicLandmark:   n('Institution_OR_Clinic_Landmark'),
      instituteOrClinicPinCode:    n('Institution_OR_Clinic_Pin_Code'),

      // Doctor
      docName:        n('Doc_Name'),
      docMobileNo1:   n('Doc_Mobile_No_1'),
      docMobileNo2:   n('Doc_Mobile_No_2'),

      // Pharmacy
      pharmacyName:        n('Pharmacy_Name'),
      pharmacyAddress1:    n('Pharmacy_Address_1'),
      pharmacyAddress2:    n('Pharmacy_Address_2'),
      pharmacyLandmark:    n('Pharmacy_Landmark'),
      pharmacyPinCode:     n('Pharmacy_Pin_Code'),
      pharmacyPersonName:  n('Pharmacy_Person_Name'),
      pharmacyMobileNo1:   n('Pharmacy_Mobile_No_1'),
      pharmacyMobileNo2:   n('Pharmacy_Mobile_No_2'),

      // Business / Status
      gstNumber:            n('GST_Number'),
      status:               n('Status'),
      visitDays:            n('Visit_Days'),
      businessSlab:         n('BUSINESS_SLAB'),
      businessCat:          n('BUSINESS_CAT'),
      visitFrequencyInDays: n('VISIT_FREQUENCY_In_Days'),

      // Dates
      followupDate: raw['followupDate'],
      dateOfFirstCall: n('Date_of_1st_Call') ?? n('DateOfFirstCall'),
      openingMonth:    n('Opening_Month')    ?? n('OpeningMonth'),
      dateOfOpening:   n('Date_of_Opening')  ?? n('DateOfOpening'),
    );
  }
}

class CustomersRepository {
  final FirebaseDatabase db;
  CustomersRepository({required this.db});

  /// Live stream of all clients in /Clients as strongly-typed entries.
  Stream<List<CustomerEntry>> streamCustomers() {
    return db.ref('Clients').onValue.map((event) {
      final v = event.snapshot.value;
      return _extract(v);
    });
  }

  /// One-shot fetch (optional helper).
  Future<List<CustomerEntry>> fetchCustomersOnce() async {
    final snap = await db.ref('Clients').get();
    return _extract(snap.value);
  }

  // ---- internal mapping helpers ----
  List<CustomerEntry> _extract(dynamic raw) {
    final out = <CustomerEntry>[];

    void addIfValid(Map m) {
      // Require the three IDs to consider it a valid row
      final regionId = _s(m['regionID']);
      final areaId   = _s(m['areaID']);
      final subId    = _s(m['subareaID']);
      if (regionId.isEmpty && areaId.isEmpty && subId.isEmpty) return;

      out.add(CustomerEntry.fromMap(m));
    }

    if (raw is Map) {
      raw.forEach((_, v) {
        if (v is Map) addIfValid(v);
      });
    } else if (raw is List) {
      for (final v in raw) {
        if (v is Map) addIfValid(v);
      }
    }

    return out;
  }
}

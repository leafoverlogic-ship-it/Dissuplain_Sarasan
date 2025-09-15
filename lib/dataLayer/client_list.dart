// File: lib/dataLayer/client_list.dart

class Client {
  final String name;
  final String clinic;
  final String region;
  final String area;
  final String subArea;
  final String? avatarUrl;

  const Client({
    required this.name,
    required this.clinic,
    required this.region,
    required this.area,
    required this.subArea,
    this.avatarUrl,
  });
}

// Mock client data — replace with database calls later
const List<Client> clientsData = [
  Client(
    name: 'Abhishek Shukla',
    clinic: 'Shanti Care Center',
    region: 'Allahabad District',
    area: 'Allahabad City',
    subArea: 'Jhusi',
  ),
  Client(
    name: 'Aniruddh Verma',
    clinic: 'Sashakti Hospital',
    region: 'Allahabad District',
    area: 'Allahabad City',
    subArea: 'Civil Lines',
  ),
  Client(
    name: 'Pradeep Sinha',
    clinic: 'Dhingra Maternity Center',
    region: 'Allahabad District',
    area: 'Allahabad City',
    subArea: 'Lukerganj',
  ),
  Client(
    name: 'Madan Mishra',
    clinic: 'Romeo Hospital',
    region: 'Allahabad District',
    area: 'Karchana',
    subArea: 'Shankargarh',
  ),
  Client(
    name: 'Jhanvi Nath',
    clinic: 'Juliet Care Center',
    region: 'Allahabad District',
    area: 'Meja',
    subArea: 'Meja Town',
  ),
  Client(
    name: 'Rohit Tandon',
    clinic: 'City Health Point',
    region: 'Varanasi District',
    area: 'Varanasi City',
    subArea: 'Sigra',
  ),
  Client(
    name: 'Neha Saxena',
    clinic: 'Kashi Wellness',
    region: 'Varanasi District',
    area: 'Pindra',
    subArea: 'Pindra Bazar',
  ),
  Client(
    name: 'Ayan Kapoor',
    clinic: 'Harahua Clinic',
    region: 'Varanasi District',
    area: 'Rohaniya',
    subArea: 'Harahua',
  ),
  Client(
    name: 'Ishita Rawat',
    clinic: 'Hazratganj Polyclinic',
    region: 'Lucknow District',
    area: 'Lucknow City',
    subArea: 'Hazratganj',
  ),
  Client(
    name: 'Rajeev Tomar',
    clinic: 'Alambagh Health Hub',
    region: 'Lucknow District',
    area: 'Lucknow City',
    subArea: 'Alambagh',
  ),
];

import 'package:firebase_database/firebase_database.dart';

Future<void> deleteAllClients() async {
  final databaseRef = FirebaseDatabase.instance.ref('Clients');

  try {
    await databaseRef.remove();
    print('All Clients data deleted successfully.');
  } catch (e) {
    print('Error deleting Clients data: $e');
  }
}

Future<void> deleteAllRegions() async {
  final databaseRef = FirebaseDatabase.instance.ref('Regions');

  try {
    await databaseRef.remove();
    print('All Regions data deleted successfully.');
  } catch (e) {
    print('Error deleting Regions data: $e');
  }
}

Future<void> deleteAllAreas() async {
  final databaseRef = FirebaseDatabase.instance.ref('Areas');

  try {
    await databaseRef.remove();
    print('All Areas data deleted successfully.');
  } catch (e) {
    print('Error deleting Areas data: $e');
  }
}

Future<void> deleteAllSubAreas() async {
  final databaseRef = FirebaseDatabase.instance.ref('SubAreas');

  try {
    await databaseRef.remove();
    print('All SubAreas data deleted successfully.');
  } catch (e) {
    print('Error deleting SubAreas data: $e');
  }
}

Future<void> deleteAllUsers() async {
  final databaseRef = FirebaseDatabase.instance.ref('Users');

  try {
    await databaseRef.remove();
    print('All Users data deleted successfully.');
  } catch (e) {
    print('Error deleting Users data: $e');
  }
}

Future<void> deleteAllCategories() async {
  final databaseRef = FirebaseDatabase.instance.ref('Categories');

  try {
    await databaseRef.remove();
    print('All Categories data deleted successfully.');
  } catch (e) {
    print('Error deleting Categories data: $e');
  }
}

Future<void> deleteAllProducts() async {
  final databaseRef = FirebaseDatabase.instance.ref('Products');

  try {
    await databaseRef.remove();
    print('All Products data deleted successfully.');
  } catch (e) {
    print('Error deleting Products data: $e');
  }
}

Future<void> deleteAllDistributors() async {
  final databaseRef = FirebaseDatabase.instance.ref('Distributors');
  try {
    await databaseRef.remove();
    print('All Distributors data deleted successfully.');
  } catch (e) {
    print('Error deleting Distributors data: $e');
  }
}

Future<void> deleteAllProductCategory() async {
  final databaseRef = FirebaseDatabase.instance.ref('ProductCategory');
  try {
    await databaseRef.remove();
    print('All ProductCategory data deleted successfully.');
  } catch (e) {
    print('Error deleting ProductCategory data: $e');
  }
}


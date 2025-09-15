import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('Regions');

void insertsRegionData() async {
databaseRef.child('1').set({'regionId': '1', 'regionName': 'Varanasi Region', 'regionalManagerID': ''});
databaseRef.child('2').set({'regionId': '2', 'regionName': 'Ayodhya Region', 'regionalManagerID': ''});
databaseRef.child('3').set({'regionId': '3', 'regionName': 'Prayagraj Region', 'regionalManagerID': ''});
}

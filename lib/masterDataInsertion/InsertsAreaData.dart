import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('Areas');

void insertsAreaData() async {
databaseRef.child('1').set({'regionId': '1', 'areaID': '1', 'areaManagerUserID': 'SS-1124', 'areaName': 'Varanasi'});
databaseRef.child('2').set({'regionId': '1', 'areaID': '2', 'areaManagerUserID': 'SS-1124', 'areaName': 'Jaunpur'});
databaseRef.child('3').set({'regionId': '1', 'areaID': '3', 'areaManagerUserID': 'SS-1124', 'areaName': 'Mirzapur'});
databaseRef.child('4').set({'regionId': '1', 'areaID': '4', 'areaManagerUserID': 'SS-1124', 'areaName': 'Bhadohi'});
databaseRef.child('5').set({'regionId': '1', 'areaID': '5', 'areaManagerUserID': 'SS-1124', 'areaName': 'Azamgarh'});
databaseRef.child('6').set({'regionId': '2', 'areaID': '6', 'areaManagerUserID': 'SS-1124', 'areaName': 'Ayodhya'});
databaseRef.child('7').set({'regionId': '1', 'areaID': '7', 'areaManagerUserID': 'SS-1124', 'areaName': 'Chandauli'});
databaseRef.child('8').set({'regionId': '3', 'areaID': '8', 'areaManagerUserID': 'SS-1124', 'areaName': 'Prayagraj'});
databaseRef.child('9').set({'regionId': '4', 'areaID': '9', 'areaManagerUserID': 'SS-1124', 'areaName': 'Gorakhpur'});
databaseRef.child('10').set({'regionId': '3', 'areaID': '10', 'areaManagerUserID': 'SS-1124', 'areaName': 'Kaushambi'});
}

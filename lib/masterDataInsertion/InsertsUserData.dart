import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref('Users');

void insertsUserData() async {
databaseRef.child('1').set({'SalesPersonID': 'SS-1111', 'salesPersonRoleID': '7', 'SalesPersonName': 'Ashwini Tripathi', 'ReportingPersonID': '', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('2').set({'SalesPersonID': 'SS-1112', 'salesPersonRoleID': '6', 'SalesPersonName': 'Dr. Pramesh Srivastava', 'ReportingPersonID': 'SS-1111', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('3').set({'SalesPersonID': 'SS-1114', 'salesPersonRoleID': '4', 'SalesPersonName': 'Jalaj Kumar Sharma', 'ReportingPersonID': 'SS-1111', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('4').set({'SalesPersonID': 'SS-1124', 'salesPersonRoleID': '2', 'SalesPersonName': 'Sher Bahadur Pal', 'ReportingPersonID': 'SS-1111', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('5').set({'SalesPersonID': 'SS-1135', 'salesPersonRoleID': '5', 'SalesPersonName': 'Matsyendra Nath Sharma', 'ReportingPersonID': 'SS-1111', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('6').set({'SalesPersonID': 'SS-1130', 'salesPersonRoleID': '1', 'SalesPersonName': 'Vivek Vishwakarma', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('7').set({'SalesPersonID': 'SS-1132', 'salesPersonRoleID': '1', 'SalesPersonName': 'Yashwant Yadav', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('8').set({'SalesPersonID': 'SS-1133', 'salesPersonRoleID': '1', 'SalesPersonName': 'Navin Kumar Mishra', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('9').set({'SalesPersonID': 'SS-1135', 'salesPersonRoleID': '1', 'SalesPersonName': 'Awadesh Kumar', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('10').set({'SalesPersonID': 'UU-0001', 'salesPersonRoleID': '1', 'SalesPersonName': 'Unassigned', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('11').set({'SalesPersonID': 'SS-1131', 'salesPersonRoleID': '1', 'SalesPersonName': 'Adarsh Pandey', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
databaseRef.child('12').set({'SalesPersonID': 'SS-1136', 'salesPersonRoleID': '1', 'SalesPersonName': 'Nitish Pandey', 'ReportingPersonID': 'SS-1124', 'phoneNumber': '1234567890', 'emailAddress': 'abc@gmail.com', 'loginPwd': 'Welcome@123'});
}

import 'package:flutter_test/flutter_test.dart';

import 'package:dissuplain_app_web_mobile/dataLayer/users_repository.dart';

void main() {
  test('filterUsersByRoleId returns only role 1 users', () {
    final users = [
      const UserEntry(
        salesPersonId: 'SP-1',
        salesPersonName: 'Alice',
        emailAddress: 'alice@example.com',
        phoneNumber: '111',
        salesPersonRoleId: '1',
        reportingPersonId: '',
        loginPwd: '',
      ),
      const UserEntry(
        salesPersonId: 'SP-2',
        salesPersonName: 'Bob',
        emailAddress: 'bob@example.com',
        phoneNumber: '222',
        salesPersonRoleId: '2',
        reportingPersonId: '',
        loginPwd: '',
      ),
      const UserEntry(
        salesPersonId: 'SP-3',
        salesPersonName: 'Carol',
        emailAddress: 'carol@example.com',
        phoneNumber: '333',
        salesPersonRoleId: '1',
        reportingPersonId: '',
        loginPwd: '',
      ),
    ];

    final filtered = filterUsersByRoleId(users, roleId: '1');

    expect(filtered, hasLength(2));
    expect(filtered.map((u) => u.salesPersonName), containsAll(<String>['Alice', 'Carol']));
    expect(filtered.every((u) => u.salesPersonRoleId == '1'), isTrue);
  });
}

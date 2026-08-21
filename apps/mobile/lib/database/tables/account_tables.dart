import 'package:drift/drift.dart';

@DataClassName('AccountIdentityRow')
class AccountIdentities extends Table {
  @override
  String get tableName => 'account_identities';

  TextColumn get id => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_user_relationships_client', columns: {#clientId})
@TableIndex(name: 'idx_user_relationships_professional', columns: {#professionalId})
@TableIndex(name: 'idx_user_relationships_status', columns: {#consentStatus})
@DataClassName('UserRelationshipRow')
class UserRelationships extends Table {
  @override
  String get tableName => 'user_relationships';

  TextColumn get id => text()();
  @ReferenceName('client_account')
  TextColumn get clientId =>
      text().named('client_id').references(AccountIdentities, #id)();
  @ReferenceName('professional_account')
  TextColumn get professionalId =>
      text().named('professional_id').references(AccountIdentities, #id)();
  TextColumn get relationshipType => text().named('relationship_type')();
  TextColumn get consentStatus => text().named('consent_status')();
  TextColumn get agreedScope =>
      text().named('agreed_scope').withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AccountProStatusRow')
class AccountProStatus extends Table {
  @override
  String get tableName => 'account_pro_status';

  IntColumn get id => integer()();
  IntColumn get isPro => integer().named('is_pro').withDefault(const Constant(0))();
  TextColumn get tier => text().withDefault(const Constant('free'))();
  TextColumn get source => text().withDefault(const Constant('unknown'))();
  TextColumn get entitlementIdsJson =>
      text().named('entitlement_ids_json').withDefault(const Constant('[]'))();
  IntColumn get billingConnected =>
      integer().named('billing_connected').withDefault(const Constant(0))();
  TextColumn get syncedFrom =>
      text().named('synced_from').withDefault(const Constant('unknown'))();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

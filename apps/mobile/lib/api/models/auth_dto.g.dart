// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$AuthUserDtoToJson(AuthUserDto instance) =>
    <String, dynamic>{'id': instance.id, 'email': instance.email};

Map<String, dynamic> _$AuthSessionDtoToJson(AuthSessionDto instance) =>
    <String, dynamic>{'user': instance.user, 'signedInAt': instance.signedInAt};

Map<String, dynamic> _$AuthVerifyDataDtoToJson(AuthVerifyDataDto instance) =>
    <String, dynamic>{'session': instance.session};

Map<String, dynamic> _$AuthSessionDataDtoToJson(AuthSessionDataDto instance) =>
    <String, dynamic>{'session': instance.session};

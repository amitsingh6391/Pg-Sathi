// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'phone_auth_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhoneAuthState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PhoneAuthState()';
}


}

/// @nodoc
class $PhoneAuthStateCopyWith<$Res>  {
$PhoneAuthStateCopyWith(PhoneAuthState _, $Res Function(PhoneAuthState) __);
}


/// Adds pattern-matching-related methods to [PhoneAuthState].
extension PhoneAuthStatePatterns on PhoneAuthState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PhoneAuthInitial value)?  initial,TResult Function( PhoneAuthSendingOtp value)?  sendingOtp,TResult Function( PhoneAuthOtpSent value)?  otpSent,TResult Function( PhoneAuthVerifyingOtp value)?  verifyingOtp,TResult Function( PhoneAuthCheckingAuth value)?  checkingAuth,TResult Function( PhoneAuthAuthenticated value)?  authenticated,TResult Function( PhoneAuthSigningOut value)?  signingOut,TResult Function( PhoneAuthSignedOut value)?  signedOut,TResult Function( PhoneAuthError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PhoneAuthInitial() when initial != null:
return initial(_that);case PhoneAuthSendingOtp() when sendingOtp != null:
return sendingOtp(_that);case PhoneAuthOtpSent() when otpSent != null:
return otpSent(_that);case PhoneAuthVerifyingOtp() when verifyingOtp != null:
return verifyingOtp(_that);case PhoneAuthCheckingAuth() when checkingAuth != null:
return checkingAuth(_that);case PhoneAuthAuthenticated() when authenticated != null:
return authenticated(_that);case PhoneAuthSigningOut() when signingOut != null:
return signingOut(_that);case PhoneAuthSignedOut() when signedOut != null:
return signedOut(_that);case PhoneAuthError() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PhoneAuthInitial value)  initial,required TResult Function( PhoneAuthSendingOtp value)  sendingOtp,required TResult Function( PhoneAuthOtpSent value)  otpSent,required TResult Function( PhoneAuthVerifyingOtp value)  verifyingOtp,required TResult Function( PhoneAuthCheckingAuth value)  checkingAuth,required TResult Function( PhoneAuthAuthenticated value)  authenticated,required TResult Function( PhoneAuthSigningOut value)  signingOut,required TResult Function( PhoneAuthSignedOut value)  signedOut,required TResult Function( PhoneAuthError value)  error,}){
final _that = this;
switch (_that) {
case PhoneAuthInitial():
return initial(_that);case PhoneAuthSendingOtp():
return sendingOtp(_that);case PhoneAuthOtpSent():
return otpSent(_that);case PhoneAuthVerifyingOtp():
return verifyingOtp(_that);case PhoneAuthCheckingAuth():
return checkingAuth(_that);case PhoneAuthAuthenticated():
return authenticated(_that);case PhoneAuthSigningOut():
return signingOut(_that);case PhoneAuthSignedOut():
return signedOut(_that);case PhoneAuthError():
return error(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PhoneAuthInitial value)?  initial,TResult? Function( PhoneAuthSendingOtp value)?  sendingOtp,TResult? Function( PhoneAuthOtpSent value)?  otpSent,TResult? Function( PhoneAuthVerifyingOtp value)?  verifyingOtp,TResult? Function( PhoneAuthCheckingAuth value)?  checkingAuth,TResult? Function( PhoneAuthAuthenticated value)?  authenticated,TResult? Function( PhoneAuthSigningOut value)?  signingOut,TResult? Function( PhoneAuthSignedOut value)?  signedOut,TResult? Function( PhoneAuthError value)?  error,}){
final _that = this;
switch (_that) {
case PhoneAuthInitial() when initial != null:
return initial(_that);case PhoneAuthSendingOtp() when sendingOtp != null:
return sendingOtp(_that);case PhoneAuthOtpSent() when otpSent != null:
return otpSent(_that);case PhoneAuthVerifyingOtp() when verifyingOtp != null:
return verifyingOtp(_that);case PhoneAuthCheckingAuth() when checkingAuth != null:
return checkingAuth(_that);case PhoneAuthAuthenticated() when authenticated != null:
return authenticated(_that);case PhoneAuthSigningOut() when signingOut != null:
return signingOut(_that);case PhoneAuthSignedOut() when signedOut != null:
return signedOut(_that);case PhoneAuthError() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( UserRole selectedRole)?  initial,TResult Function( String phoneNumber,  UserRole selectedRole)?  sendingOtp,TResult Function( String phoneNumber,  String verificationId,  UserRole selectedRole)?  otpSent,TResult Function( String phoneNumber,  String verificationId,  UserRole selectedRole)?  verifyingOtp,TResult Function()?  checkingAuth,TResult Function( User user)?  authenticated,TResult Function()?  signingOut,TResult Function()?  signedOut,TResult Function( Failure failure,  String? phoneNumber,  String? verificationId,  UserRole selectedRole)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PhoneAuthInitial() when initial != null:
return initial(_that.selectedRole);case PhoneAuthSendingOtp() when sendingOtp != null:
return sendingOtp(_that.phoneNumber,_that.selectedRole);case PhoneAuthOtpSent() when otpSent != null:
return otpSent(_that.phoneNumber,_that.verificationId,_that.selectedRole);case PhoneAuthVerifyingOtp() when verifyingOtp != null:
return verifyingOtp(_that.phoneNumber,_that.verificationId,_that.selectedRole);case PhoneAuthCheckingAuth() when checkingAuth != null:
return checkingAuth();case PhoneAuthAuthenticated() when authenticated != null:
return authenticated(_that.user);case PhoneAuthSigningOut() when signingOut != null:
return signingOut();case PhoneAuthSignedOut() when signedOut != null:
return signedOut();case PhoneAuthError() when error != null:
return error(_that.failure,_that.phoneNumber,_that.verificationId,_that.selectedRole);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( UserRole selectedRole)  initial,required TResult Function( String phoneNumber,  UserRole selectedRole)  sendingOtp,required TResult Function( String phoneNumber,  String verificationId,  UserRole selectedRole)  otpSent,required TResult Function( String phoneNumber,  String verificationId,  UserRole selectedRole)  verifyingOtp,required TResult Function()  checkingAuth,required TResult Function( User user)  authenticated,required TResult Function()  signingOut,required TResult Function()  signedOut,required TResult Function( Failure failure,  String? phoneNumber,  String? verificationId,  UserRole selectedRole)  error,}) {final _that = this;
switch (_that) {
case PhoneAuthInitial():
return initial(_that.selectedRole);case PhoneAuthSendingOtp():
return sendingOtp(_that.phoneNumber,_that.selectedRole);case PhoneAuthOtpSent():
return otpSent(_that.phoneNumber,_that.verificationId,_that.selectedRole);case PhoneAuthVerifyingOtp():
return verifyingOtp(_that.phoneNumber,_that.verificationId,_that.selectedRole);case PhoneAuthCheckingAuth():
return checkingAuth();case PhoneAuthAuthenticated():
return authenticated(_that.user);case PhoneAuthSigningOut():
return signingOut();case PhoneAuthSignedOut():
return signedOut();case PhoneAuthError():
return error(_that.failure,_that.phoneNumber,_that.verificationId,_that.selectedRole);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( UserRole selectedRole)?  initial,TResult? Function( String phoneNumber,  UserRole selectedRole)?  sendingOtp,TResult? Function( String phoneNumber,  String verificationId,  UserRole selectedRole)?  otpSent,TResult? Function( String phoneNumber,  String verificationId,  UserRole selectedRole)?  verifyingOtp,TResult? Function()?  checkingAuth,TResult? Function( User user)?  authenticated,TResult? Function()?  signingOut,TResult? Function()?  signedOut,TResult? Function( Failure failure,  String? phoneNumber,  String? verificationId,  UserRole selectedRole)?  error,}) {final _that = this;
switch (_that) {
case PhoneAuthInitial() when initial != null:
return initial(_that.selectedRole);case PhoneAuthSendingOtp() when sendingOtp != null:
return sendingOtp(_that.phoneNumber,_that.selectedRole);case PhoneAuthOtpSent() when otpSent != null:
return otpSent(_that.phoneNumber,_that.verificationId,_that.selectedRole);case PhoneAuthVerifyingOtp() when verifyingOtp != null:
return verifyingOtp(_that.phoneNumber,_that.verificationId,_that.selectedRole);case PhoneAuthCheckingAuth() when checkingAuth != null:
return checkingAuth();case PhoneAuthAuthenticated() when authenticated != null:
return authenticated(_that.user);case PhoneAuthSigningOut() when signingOut != null:
return signingOut();case PhoneAuthSignedOut() when signedOut != null:
return signedOut();case PhoneAuthError() when error != null:
return error(_that.failure,_that.phoneNumber,_that.verificationId,_that.selectedRole);case _:
  return null;

}
}

}

/// @nodoc


class PhoneAuthInitial extends PhoneAuthState {
  const PhoneAuthInitial({this.selectedRole = UserRole.student}): super._();
  

@JsonKey() final  UserRole selectedRole;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneAuthInitialCopyWith<PhoneAuthInitial> get copyWith => _$PhoneAuthInitialCopyWithImpl<PhoneAuthInitial>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthInitial&&(identical(other.selectedRole, selectedRole) || other.selectedRole == selectedRole));
}


@override
int get hashCode => Object.hash(runtimeType,selectedRole);

@override
String toString() {
  return 'PhoneAuthState.initial(selectedRole: $selectedRole)';
}


}

/// @nodoc
abstract mixin class $PhoneAuthInitialCopyWith<$Res> implements $PhoneAuthStateCopyWith<$Res> {
  factory $PhoneAuthInitialCopyWith(PhoneAuthInitial value, $Res Function(PhoneAuthInitial) _then) = _$PhoneAuthInitialCopyWithImpl;
@useResult
$Res call({
 UserRole selectedRole
});




}
/// @nodoc
class _$PhoneAuthInitialCopyWithImpl<$Res>
    implements $PhoneAuthInitialCopyWith<$Res> {
  _$PhoneAuthInitialCopyWithImpl(this._self, this._then);

  final PhoneAuthInitial _self;
  final $Res Function(PhoneAuthInitial) _then;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? selectedRole = null,}) {
  return _then(PhoneAuthInitial(
selectedRole: null == selectedRole ? _self.selectedRole : selectedRole // ignore: cast_nullable_to_non_nullable
as UserRole,
  ));
}


}

/// @nodoc


class PhoneAuthSendingOtp extends PhoneAuthState {
  const PhoneAuthSendingOtp({required this.phoneNumber, this.selectedRole = UserRole.student}): super._();
  

 final  String phoneNumber;
@JsonKey() final  UserRole selectedRole;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneAuthSendingOtpCopyWith<PhoneAuthSendingOtp> get copyWith => _$PhoneAuthSendingOtpCopyWithImpl<PhoneAuthSendingOtp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthSendingOtp&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.selectedRole, selectedRole) || other.selectedRole == selectedRole));
}


@override
int get hashCode => Object.hash(runtimeType,phoneNumber,selectedRole);

@override
String toString() {
  return 'PhoneAuthState.sendingOtp(phoneNumber: $phoneNumber, selectedRole: $selectedRole)';
}


}

/// @nodoc
abstract mixin class $PhoneAuthSendingOtpCopyWith<$Res> implements $PhoneAuthStateCopyWith<$Res> {
  factory $PhoneAuthSendingOtpCopyWith(PhoneAuthSendingOtp value, $Res Function(PhoneAuthSendingOtp) _then) = _$PhoneAuthSendingOtpCopyWithImpl;
@useResult
$Res call({
 String phoneNumber, UserRole selectedRole
});




}
/// @nodoc
class _$PhoneAuthSendingOtpCopyWithImpl<$Res>
    implements $PhoneAuthSendingOtpCopyWith<$Res> {
  _$PhoneAuthSendingOtpCopyWithImpl(this._self, this._then);

  final PhoneAuthSendingOtp _self;
  final $Res Function(PhoneAuthSendingOtp) _then;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phoneNumber = null,Object? selectedRole = null,}) {
  return _then(PhoneAuthSendingOtp(
phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,selectedRole: null == selectedRole ? _self.selectedRole : selectedRole // ignore: cast_nullable_to_non_nullable
as UserRole,
  ));
}


}

/// @nodoc


class PhoneAuthOtpSent extends PhoneAuthState {
  const PhoneAuthOtpSent({required this.phoneNumber, required this.verificationId, this.selectedRole = UserRole.student}): super._();
  

 final  String phoneNumber;
 final  String verificationId;
@JsonKey() final  UserRole selectedRole;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneAuthOtpSentCopyWith<PhoneAuthOtpSent> get copyWith => _$PhoneAuthOtpSentCopyWithImpl<PhoneAuthOtpSent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthOtpSent&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.verificationId, verificationId) || other.verificationId == verificationId)&&(identical(other.selectedRole, selectedRole) || other.selectedRole == selectedRole));
}


@override
int get hashCode => Object.hash(runtimeType,phoneNumber,verificationId,selectedRole);

@override
String toString() {
  return 'PhoneAuthState.otpSent(phoneNumber: $phoneNumber, verificationId: $verificationId, selectedRole: $selectedRole)';
}


}

/// @nodoc
abstract mixin class $PhoneAuthOtpSentCopyWith<$Res> implements $PhoneAuthStateCopyWith<$Res> {
  factory $PhoneAuthOtpSentCopyWith(PhoneAuthOtpSent value, $Res Function(PhoneAuthOtpSent) _then) = _$PhoneAuthOtpSentCopyWithImpl;
@useResult
$Res call({
 String phoneNumber, String verificationId, UserRole selectedRole
});




}
/// @nodoc
class _$PhoneAuthOtpSentCopyWithImpl<$Res>
    implements $PhoneAuthOtpSentCopyWith<$Res> {
  _$PhoneAuthOtpSentCopyWithImpl(this._self, this._then);

  final PhoneAuthOtpSent _self;
  final $Res Function(PhoneAuthOtpSent) _then;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phoneNumber = null,Object? verificationId = null,Object? selectedRole = null,}) {
  return _then(PhoneAuthOtpSent(
phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,verificationId: null == verificationId ? _self.verificationId : verificationId // ignore: cast_nullable_to_non_nullable
as String,selectedRole: null == selectedRole ? _self.selectedRole : selectedRole // ignore: cast_nullable_to_non_nullable
as UserRole,
  ));
}


}

/// @nodoc


class PhoneAuthVerifyingOtp extends PhoneAuthState {
  const PhoneAuthVerifyingOtp({required this.phoneNumber, required this.verificationId, this.selectedRole = UserRole.student}): super._();
  

 final  String phoneNumber;
 final  String verificationId;
@JsonKey() final  UserRole selectedRole;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneAuthVerifyingOtpCopyWith<PhoneAuthVerifyingOtp> get copyWith => _$PhoneAuthVerifyingOtpCopyWithImpl<PhoneAuthVerifyingOtp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthVerifyingOtp&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.verificationId, verificationId) || other.verificationId == verificationId)&&(identical(other.selectedRole, selectedRole) || other.selectedRole == selectedRole));
}


@override
int get hashCode => Object.hash(runtimeType,phoneNumber,verificationId,selectedRole);

@override
String toString() {
  return 'PhoneAuthState.verifyingOtp(phoneNumber: $phoneNumber, verificationId: $verificationId, selectedRole: $selectedRole)';
}


}

/// @nodoc
abstract mixin class $PhoneAuthVerifyingOtpCopyWith<$Res> implements $PhoneAuthStateCopyWith<$Res> {
  factory $PhoneAuthVerifyingOtpCopyWith(PhoneAuthVerifyingOtp value, $Res Function(PhoneAuthVerifyingOtp) _then) = _$PhoneAuthVerifyingOtpCopyWithImpl;
@useResult
$Res call({
 String phoneNumber, String verificationId, UserRole selectedRole
});




}
/// @nodoc
class _$PhoneAuthVerifyingOtpCopyWithImpl<$Res>
    implements $PhoneAuthVerifyingOtpCopyWith<$Res> {
  _$PhoneAuthVerifyingOtpCopyWithImpl(this._self, this._then);

  final PhoneAuthVerifyingOtp _self;
  final $Res Function(PhoneAuthVerifyingOtp) _then;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? phoneNumber = null,Object? verificationId = null,Object? selectedRole = null,}) {
  return _then(PhoneAuthVerifyingOtp(
phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,verificationId: null == verificationId ? _self.verificationId : verificationId // ignore: cast_nullable_to_non_nullable
as String,selectedRole: null == selectedRole ? _self.selectedRole : selectedRole // ignore: cast_nullable_to_non_nullable
as UserRole,
  ));
}


}

/// @nodoc


class PhoneAuthCheckingAuth extends PhoneAuthState {
  const PhoneAuthCheckingAuth(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthCheckingAuth);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PhoneAuthState.checkingAuth()';
}


}




/// @nodoc


class PhoneAuthAuthenticated extends PhoneAuthState {
  const PhoneAuthAuthenticated({required this.user}): super._();
  

 final  User user;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneAuthAuthenticatedCopyWith<PhoneAuthAuthenticated> get copyWith => _$PhoneAuthAuthenticatedCopyWithImpl<PhoneAuthAuthenticated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthAuthenticated&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,user);

@override
String toString() {
  return 'PhoneAuthState.authenticated(user: $user)';
}


}

/// @nodoc
abstract mixin class $PhoneAuthAuthenticatedCopyWith<$Res> implements $PhoneAuthStateCopyWith<$Res> {
  factory $PhoneAuthAuthenticatedCopyWith(PhoneAuthAuthenticated value, $Res Function(PhoneAuthAuthenticated) _then) = _$PhoneAuthAuthenticatedCopyWithImpl;
@useResult
$Res call({
 User user
});




}
/// @nodoc
class _$PhoneAuthAuthenticatedCopyWithImpl<$Res>
    implements $PhoneAuthAuthenticatedCopyWith<$Res> {
  _$PhoneAuthAuthenticatedCopyWithImpl(this._self, this._then);

  final PhoneAuthAuthenticated _self;
  final $Res Function(PhoneAuthAuthenticated) _then;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? user = null,}) {
  return _then(PhoneAuthAuthenticated(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,
  ));
}


}

/// @nodoc


class PhoneAuthSigningOut extends PhoneAuthState {
  const PhoneAuthSigningOut(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthSigningOut);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PhoneAuthState.signingOut()';
}


}




/// @nodoc


class PhoneAuthSignedOut extends PhoneAuthState {
  const PhoneAuthSignedOut(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthSignedOut);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PhoneAuthState.signedOut()';
}


}




/// @nodoc


class PhoneAuthError extends PhoneAuthState {
  const PhoneAuthError({required this.failure, this.phoneNumber, this.verificationId, this.selectedRole = UserRole.student}): super._();
  

 final  Failure failure;
 final  String? phoneNumber;
 final  String? verificationId;
@JsonKey() final  UserRole selectedRole;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhoneAuthErrorCopyWith<PhoneAuthError> get copyWith => _$PhoneAuthErrorCopyWithImpl<PhoneAuthError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhoneAuthError&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.verificationId, verificationId) || other.verificationId == verificationId)&&(identical(other.selectedRole, selectedRole) || other.selectedRole == selectedRole));
}


@override
int get hashCode => Object.hash(runtimeType,failure,phoneNumber,verificationId,selectedRole);

@override
String toString() {
  return 'PhoneAuthState.error(failure: $failure, phoneNumber: $phoneNumber, verificationId: $verificationId, selectedRole: $selectedRole)';
}


}

/// @nodoc
abstract mixin class $PhoneAuthErrorCopyWith<$Res> implements $PhoneAuthStateCopyWith<$Res> {
  factory $PhoneAuthErrorCopyWith(PhoneAuthError value, $Res Function(PhoneAuthError) _then) = _$PhoneAuthErrorCopyWithImpl;
@useResult
$Res call({
 Failure failure, String? phoneNumber, String? verificationId, UserRole selectedRole
});




}
/// @nodoc
class _$PhoneAuthErrorCopyWithImpl<$Res>
    implements $PhoneAuthErrorCopyWith<$Res> {
  _$PhoneAuthErrorCopyWithImpl(this._self, this._then);

  final PhoneAuthError _self;
  final $Res Function(PhoneAuthError) _then;

/// Create a copy of PhoneAuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,Object? phoneNumber = freezed,Object? verificationId = freezed,Object? selectedRole = null,}) {
  return _then(PhoneAuthError(
failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,verificationId: freezed == verificationId ? _self.verificationId : verificationId // ignore: cast_nullable_to_non_nullable
as String?,selectedRole: null == selectedRole ? _self.selectedRole : selectedRole // ignore: cast_nullable_to_non_nullable
as UserRole,
  ));
}


}

// dart format on

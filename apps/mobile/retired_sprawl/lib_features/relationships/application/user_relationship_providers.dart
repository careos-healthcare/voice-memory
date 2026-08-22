import 'package:archiveme_mobile/features/relationships/user_relationship.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship_repository.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRelationshipLoadPhase {
  idle,
  loading,
  ready,
  error,
}

class UserRelationshipState {
  const UserRelationshipState({
    this.phase = UserRelationshipLoadPhase.idle,
    this.clientRelationships = const [],
    this.professionalClients = const [],
    this.errorMessage,
  });

  final UserRelationshipLoadPhase phase;
  final List<UserRelationship> clientRelationships;
  final List<UserRelationship> professionalClients;
  final String? errorMessage;

  bool get isLoading => phase == UserRelationshipLoadPhase.loading;

  UserRelationshipState copyWith({
    UserRelationshipLoadPhase? phase,
    List<UserRelationship>? clientRelationships,
    List<UserRelationship>? professionalClients,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserRelationshipState(
      phase: phase ?? this.phase,
      clientRelationships: clientRelationships ?? this.clientRelationships,
      professionalClients: professionalClients ?? this.professionalClients,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UserRelationshipNotifier extends Notifier<UserRelationshipState> {
  @override
  UserRelationshipState build() => const UserRelationshipState();

  UserRelationshipRepository get _repository =>
      ref.read(userRelationshipRepositoryProvider);

  Future<void> loadForClient(String clientId) async {
    state = state.copyWith(
      phase: UserRelationshipLoadPhase.loading,
      clearError: true,
    );
    try {
      final rows = await _repository.listForClient(clientId);
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.ready,
        clientRelationships: rows,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadForProfessional(String professionalId) async {
    state = state.copyWith(
      phase: UserRelationshipLoadPhase.loading,
      clearError: true,
    );
    try {
      final rows =
          await _repository.getConsentingClientsForProfessional(professionalId);
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.ready,
        professionalClients: rows,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<UserRelationship?> requestProfessionalConnection({
    required String clientId,
    required String professionalId,
    required String scope,
  }) async {
    state = state.copyWith(
      phase: UserRelationshipLoadPhase.loading,
      clearError: true,
    );
    try {
      final created = await _repository.requestProfessionalConnection(
        clientId: clientId,
        professionalId: professionalId,
        scope: scope,
      );
      await loadForClient(clientId);
      return created;
    } catch (error, stackTrace) {
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.error,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<bool> updateConsentStatus({
    required String relationshipId,
    required ConsentStatus status,
    required String clientId,
  }) async {
    try {
      await _repository.updateConsentStatus(
        relationshipId: relationshipId,
        status: status,
      );
      await loadForClient(clientId);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.error,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> updateAgreedScope({
    required String relationshipId,
    required Map<String, dynamic> agreedScope,
    required String clientId,
  }) async {
    try {
      await _repository.updateAgreedScope(
        relationshipId: relationshipId,
        agreedScope: agreedScope,
      );
      await loadForClient(clientId);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        phase: UserRelationshipLoadPhase.error,
        errorMessage: error.toString(),
      );
      return false;
    }
  }
}

final userRelationshipRepositoryProvider = Provider<UserRelationshipRepository>(
  (ref) {
    if (!AppServices.isInitialized) {
      throw StateError('AppServices.initialize() required');
    }
    final repository = AppServices.instance.userRelationshipRepository;
    if (repository == null) {
      throw StateError(
        'UserRelationshipRepository requires SQLite — not available in this context',
      );
    }
    return repository;
  },
);

final userRelationshipProvider =
    NotifierProvider<UserRelationshipNotifier, UserRelationshipState>(
  UserRelationshipNotifier.new,
);
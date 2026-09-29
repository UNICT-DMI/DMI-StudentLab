import '../../../local_storage/repositories/study_plan_local_repository.dart';
import '../../../local_storage/services/study_plan_sync_service.dart';
import '../../../services/auth_session.dart';

class StudentQuizReviewService {
  final StudyPlanLocalRepository _repository;
  final StudyPlanSyncService _syncService;
  Future<void>? _preparing;

  StudentQuizReviewService({
    StudyPlanLocalRepository? repository,
    StudyPlanSyncService? syncService,
  }) : _repository = repository ?? StudyPlanLocalRepository(),
       _syncService = syncService ?? StudyPlanSyncService();

  Future<void> _prepare() {
    final Future<void>? current = _preparing;
    if (current != null) return current;

    final Future<void> operation = _prepareInternal();
    _preparing = operation;
    return operation.whenComplete(() {
      if (identical(_preparing, operation)) {
        _preparing = null;
      }
    });
  }

  Future<void> _prepareInternal() async {
    if (AuthSession.instance.isGuest) {
      await _syncService.refreshGuestPlan();
      return;
    }

    final int? userId = AuthSession.instance.currentUserId;
    if (userId == null) return;

    try {
      await _syncService.onAuthenticated(userId);
    } catch (_) {
      // Il Ripasso locale resta utilizzabile anche senza rete.
    }
  }

  Future<Map<String, dynamic>> getOverall() async {
    await _prepare();
    return _repository.getOverall();
  }

  Future<List<Map<String, dynamic>>> getSubjects() async {
    await _prepare();
    return _repository.getSubjects();
  }

  Future<List<Map<String, dynamic>>> getArguments({
    String? department,
    String? course,
    String? subject,
  }) async {
    await _prepare();
    return _repository.getArguments(
      department: department,
      course: course,
      subject: subject,
    );
  }

  Future<List<Map<String, dynamic>>> getWeakArguments({
    String? department,
    String? course,
    String? subject,
    double maximumAccuracy = 70,
    int minimumAnswers = 1,
  }) async {
    await _prepare();
    return _repository.getWeakArguments(
      department: department,
      course: course,
      subject: subject,
      maximumAccuracy: maximumAccuracy,
      minimumAnswers: minimumAnswers,
    );
  }

  Future<List<Map<String, dynamic>>> getReview({
    String? department,
    String? course,
    String? subject,
    String? argument,
    bool includeCorrect = false,
  }) async {
    await _prepare();
    return _repository.getReview(
      department: department,
      course: course,
      subject: subject,
      argument: argument,
      includeCorrect: includeCorrect,
    );
  }

  Future<List<Map<String, dynamic>>> getSources() async {
    await _prepare();
    return _repository.getSources();
  }

  Future<void> setSourceEnabled(String sourceKey, bool enabled) async {
    await _repository.setSourceEnabled(sourceKey, enabled);
  }

  Future<void> removeLocalSource(String sourceKey) async {
    await _repository.removeSource(sourceKey);
  }

  Future<Map<String, dynamic>> setRemoteSessionEnabled(
    String sessionUuid,
    bool enabled,
  ) async {
    final Map<String, dynamic> result =
        await _syncService.setRemoteSessionEnabled(sessionUuid, enabled);

    final int? userId = AuthSession.instance.currentUserId;
    if (userId != null) {
      try {
        await _syncService.refreshRemote(userId);
      } catch (_) {}
    }
    return result;
  }

  Future<void> refresh() async {
    _preparing = null;
    await _prepare();
  }
}

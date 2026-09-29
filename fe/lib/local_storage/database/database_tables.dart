class DatabaseTables {
  DatabaseTables._();

  static const String materialFiles =
      'material_files';

  static const String materials =
      'materials';

  static const String materialDownloads =
      'material_downloads';

  static const String materialSyncState =
      'material_sync_state';

  static const String pendingUploads =
      'pending_uploads';

  static const String downloadedMaterials =
      'downloaded_materials';

  static const String materialCache =
      'material_cache';

  static const String localFileBlobs =
      'local_file_blobs';
  static const String quizAttempts =
      'quiz_attempts_local';

  static const String quizAttemptAnswers =
      'quiz_attempt_answers_local';

  static const String studyPlanSources =
      'study_plan_sources_local';

  static const String studyPlanItems =
      'study_plan_items_local';

  static const String studyPlanContributions =
      'study_plan_contributions_local';

  static const String studyPlanProgress =
      'study_plan_progress_local';

  // v14 · flashcard con ripetizione dilazionata (ospite o prima della sincronizzazione)
  static const String flashcardReviewsLocal =
      'flashcard_reviews_local';

}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/feedback/models/system_feedback_model.dart';
import 'package:mobile/features/feedback/services/feedback_service.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

final userFeedbacksProvider =
    FutureProvider.autoDispose<List<SystemFeedbackModel>>((ref) async {
      final service = ref.watch(feedbackServiceProvider);
      return service.getUserFeedbacks();
    });

class FeedbackSubmitState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  FeedbackSubmitState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  FeedbackSubmitState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return FeedbackSubmitState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class FeedbackSubmitNotifier extends Notifier<FeedbackSubmitState> {
  @override
  FeedbackSubmitState build() => FeedbackSubmitState();

  Future<bool> submitFeedback({
    required String category,
    required String subject,
    required String message,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final service = ref.read(feedbackServiceProvider);
      await service.submitFeedback(
        category: category,
        subject: subject,
        message: message,
      );
      // Invalidate history list to reload fresh data
      ref.invalidate(userFeedbacksProvider);
      state = FeedbackSubmitState(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = FeedbackSubmitState(
        isLoading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  void reset() {
    state = FeedbackSubmitState();
  }
}

final feedbackSubmitProvider =
    NotifierProvider.autoDispose<FeedbackSubmitNotifier, FeedbackSubmitState>(
      FeedbackSubmitNotifier.new,
    );

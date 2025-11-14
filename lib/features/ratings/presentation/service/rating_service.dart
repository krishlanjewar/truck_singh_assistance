import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RatingService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> submitRating({
    required String shipmentId,
    required String raterId,
    required String raterRole,
    required double ratingForCreator,
    required double ratingForDriver,
    required String feedbackCreator,
    required String feedbackDriver,
    String? creatorId,
    String? driverId,
  }) async {
    if (creatorId == null && driverId == null) {
      throw Exception("No valid creator or driver ID provided");
    }

    // Prepare ratings list
    List<Map<String, dynamic>> ratingsToSubmit = [];

    void addRating({
      required String rateeId,
      required String rateeRole,
      required double rating,
      required String feedback,
    }) {
      ratingsToSubmit.add({
        'shipment_id': shipmentId,
        'rater_id': raterId,
        'ratee_id': rateeId,
        'rater_role': raterRole,
        'ratee_role': rateeRole,
        'rating': rating.round(),
        'feedback': feedback.isNotEmpty ? feedback : null,
      });
    }

    if (creatorId != null) {
      addRating(
        rateeId: creatorId,
        rateeRole: 'Creator',
        rating: ratingForCreator,
        feedback: feedbackCreator,
      );
    }

    if (driverId != null) {
      addRating(
        rateeId: driverId,
        rateeRole: 'Driver',
        rating: ratingForDriver,
        feedback: feedbackDriver,
      );
    }

    // Submit/upsert ratings with edit count check
    for (final rating in ratingsToSubmit) {
      final existingRating = await _client
          .from('ratings')
          .select('edit_count')
          .eq('shipment_id', rating['shipment_id'])
          .eq('rater_id', rating['rater_id'])
          .eq('ratee_id', rating['ratee_id'])
          .maybeSingle();

      int currentEditCount = existingRating?['edit_count'] as int? ?? 0;

      if (currentEditCount >= 3) {
        throw Exception("Edit limit reached for this rating");
      }

      rating['edit_count'] = currentEditCount + 1;

      await _client
          .from('ratings')
          .upsert(rating, onConflict: 'shipment_id,rater_id,ratee_id')
          .select();

      if (kDebugMode) debugPrint("Rating submitted: $rating");
    }
  }
}
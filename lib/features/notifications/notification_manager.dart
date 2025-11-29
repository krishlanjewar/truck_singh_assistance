import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

/// Central notification management service for the shipment app.
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> createNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    String sourceType = 'app',
    String? sourceId,
  }) async {
    try {
      final result = await _supabase.rpc(
        'create_smart_notification',
        params: {
          'p_user_id': userId,
          'p_title': title,
          'p_message': message,
          'p_type': type,
          'p_source_type': sourceType,
          'p_source_id': sourceId,
        },
      );

      if (kDebugMode) {
        debugPrint('✅ ${tr("notification_created_for_user")}: $userId: $title');
      }

      return result as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ${tr("error_creating_notification")}: $e');
      }
      return null;
    }
  }

  /// Marks a notification as processed (RPC)
  Future<void> markNotificationProcessed(String notificationId) async {
    try {
      await _supabase.rpc(
        'mark_notification_processed',
        params: {'notification_id': notificationId},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ${tr("error_marking_notification_processed")}: $e');
      }
    }
  }

  /// Marks a notification as delivered (RPC)
  Future<void> markNotificationDelivered(String notificationId) async {
    try {
      await _supabase.rpc(
        'mark_notification_delivered',
        params: {'notification_id': notificationId},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ${tr("error_marking_notification_delivered")}: $e');
      }
    }
  }

  /// Retrieves unprocessed notifications (RPC)
  Future<List<Map<String, dynamic>>> getUnprocessedNotifications(
      String userId, {
        int limit = 10,
      }) async {
    try {
      final result = await _supabase.rpc(
        'get_unprocessed_notifications',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
        },
      );

      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ${tr("error_getting_unprocessed_notifications")}: $e');
      }
      return [];
    }
  }

  Future<void> createComplaintNotification({
    required String complainerId,
    required String complaintSubject,
    String? targetUserId,
    String? complaintId,
  }) async {
    try {
      // Notify complainer
      await createNotification(
        userId: complainerId,
        title: tr("complaint_filed_successfully"),
        message: tr("complaint_filed_message", args: [complaintSubject]),
        type: 'complaint',
        sourceType: 'app',
        sourceId: complaintId,
      );

      // Notify target user (if exists)
      if (targetUserId != null && targetUserId.isNotEmpty) {
        final targetUserProfile = await _supabase
            .from('user_profiles')
            .select('user_id')
            .eq('custom_user_id', targetUserId)
            .maybeSingle();

        final targetUserUid = targetUserProfile?['user_id'];

        if (targetUserUid != null) {
          await createNotification(
            userId: targetUserUid,
            title: tr("new_complaint_filed_against_you"),
            message: tr("complaint_against_you", args: [complaintSubject]),
            type: 'complaint',
            sourceType: 'app',
            sourceId: complaintId,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ${tr("error_creating_complaint_notification")}: $e');
      }
    }
  }

  Future<void> createComplaintStatusNotification({
    required String userId,
    required String complaintSubject,
    required String status,
    String? complaintId,
  }) async {
    String message;

    switch (status.toLowerCase()) {
      case 'justified':
        message = tr("complaint_justified", args: [complaintSubject]);
        break;
      case 'resolved':
        message = tr("complaint_resolved", args: [complaintSubject]);
        break;
      case 'rejected':
        message = tr("complaint_rejected", args: [complaintSubject]);
        break;
      case 'reverted':
        message = tr("complaint_reverted", args: [complaintSubject]);
        break;
      case 'resolved & accepted':
        message =
            tr("complaint_resolved_accepted", args: [complaintSubject]);
        break;
      case 'auto-resolved':
        message =
            tr("complaint_auto_resolved", args: [complaintSubject]);
        break;
      default:
        message = tr("complaint_status_updated",
            args: [complaintSubject, status]);
    }

    await createNotification(
      userId: userId,
      title: tr("complaint_status_updated_title"),
      message: message,
      type: 'complaint',
      sourceType: 'app',
      sourceId: complaintId,
    );
  }

  Future<void> createStatusUpdateNotification(
      String complaintId,
      String status,
      String justification,
      ) async {
    try {
      final complaint = await _supabase
          .from('complaints')
          .select('user_id, target_user_id, subject')
          .eq('id', complaintId)
          .maybeSingle();
      if (complaint == null) return;
      final complainerId = complaint['user_id'] as String;
      final targetUserCustomId = complaint['target_user_id'];
      final subject = complaint['subject'] as String;
      await createComplaintStatusNotification(
        userId: complainerId,
        complaintSubject: subject,
        status: status,
        complaintId: complaintId,
      );

      if (targetUserCustomId != null &&
          targetUserCustomId.toString().isNotEmpty) {
        final profile = await _supabase
            .from('user_profiles')
            .select('user_id')
            .eq('custom_user_id', targetUserCustomId)
            .maybeSingle();

        final targetUserUid = profile?['user_id'];

        if (targetUserUid != null) {
          await createComplaintStatusNotification(
            userId: targetUserUid,
            complaintSubject: subject,
            status: status,
            complaintId: complaintId,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ ${tr("error_creating_status_update_notification")}: $e');
      }
    }
  }

  Future<void> createShipmentNotification({
    required String userId,
    required String shipmentId,
    required String status,
    String? pickup,
    String? drop,
  }) async {
    String message;

    switch (status.toLowerCase()) {
      case 'accepted':
        message = tr("shipment_accepted",
            args: [shipmentId, pickup ?? 'pickup', drop ?? 'drop']);
        break;
      case 'in-transit':
        message = tr("shipment_in_transit",
            args: [shipmentId, pickup ?? 'pickup', drop ?? 'drop']);
        break;
      case 'delivered':
        message =
            tr("shipment_delivered", args: [shipmentId, drop ?? 'drop']);
        break;
      case 'cancelled':
        message = tr("shipment_cancelled", args: [shipmentId]);
        break;
      default:
        message =
            tr("shipment_status_updated", args: [shipmentId, status]);
    }

    await createNotification(
      userId: userId,
      title: tr("shipment_status_updated_title"),
      message: message,
      type: 'shipment',
      sourceType: 'app',
      sourceId: shipmentId,
    );
  }

  Future<void> createCustomNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'custom',
    String? sourceId,
  }) async {
    await createNotification(
      userId: userId,
      title: title,
      message: message,
      type: type,
      sourceType: 'app',
      sourceId: sourceId,
    );
  }

  Future<void> createBulkNotification({
    required List<String> userIds,
    required String title,
    required String message,
    String type = 'bulk',
    String? sourceId,
  }) async {
    for (final userId in userIds) {
      await createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        sourceType: 'app',
        sourceId: sourceId,
      );
    }
  }
}
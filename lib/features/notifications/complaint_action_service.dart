import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'notification_manager.dart';

class ComplaintActionService {
  static final ComplaintActionService _instance =
  ComplaintActionService._internal();
  factory ComplaintActionService() => _instance;
  ComplaintActionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> provideJustification(
      String complaintId, String justification) async {
    try {
      await _supabase.rpc(
        'provide_justification',
        params: {
          'complaint_id': complaintId,
          'justification_text': justification,
        },
      );

      await NotificationManager().createStatusUpdateNotification(
        complaintId,
        tr("complaint_status_justified"),
        justification,
      );

      if (kDebugMode) {
        debugPrint(tr("log_justification_provided", args: [complaintId]));
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_providing_justification")}: $e");
      }
      return false;
    }
  }

  Future<bool> acceptJustification(String complaintId) async {
    try {
      await _supabase.rpc(
        'accept_justification',
        params: {
          'complaint_id': complaintId,
        },
      );

      await NotificationManager().createStatusUpdateNotification(
        complaintId,
        tr("complaint_status_resolved"),
        tr("complaint_msg_justification_accepted"),
      );

      if (kDebugMode) {
        debugPrint(tr("log_justification_accepted", args: [complaintId]));
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_accepting_justification")}: $e");
      }
      return false;
    }
  }

  Future<bool> rejectJustification(String complaintId) async {
    try {
      await _supabase.rpc(
        'reject_justification',
        params: {
          'complaint_id': complaintId,
        },
      );

      await NotificationManager().createStatusUpdateNotification(
        complaintId,
        tr("complaint_status_reverted"),
        tr("complaint_msg_justification_rejected"),
      );

      if (kDebugMode) {
        debugPrint(tr("log_justification_rejected", args: [complaintId]));
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_rejecting_justification")}: $e");
      }
      return false;
    }
  }

  Future<bool> resolveComplaint(
      String complaintId, String status, String reason) async {
    try {
      await _supabase.rpc(
        'resolve_complaint',
        params: {
          'complaint_id': complaintId,
          'new_status': status,
          'resolution_reason': reason,
        },
      );

      await NotificationManager().createStatusUpdateNotification(
        complaintId,
        status,
        reason,
      );

      if (kDebugMode) {
        debugPrint(tr("log_complaint_resolved", args: [complaintId, status]));
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_resolving_complaint")}: $e");
      }
      return false;
    }
  }

  Future<String?> getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final profile = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      return profile?['role'] as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_getting_user_role")}: $e");
      }
      return null;
    }
  }

  Future<bool> canProvideJustification(String complaintId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profile = await _supabase
          .from('user_profiles')
          .select('custom_user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final customUserId = profile?['custom_user_id'];
      if (customUserId == null) return false;

      final complaint = await _supabase
          .from('complaints')
          .select('target_user_id, status')
          .eq('id', complaintId)
          .maybeSingle();

      if (complaint == null) return false;

      return complaint['target_user_id'] == customUserId &&
          (complaint['status'] == 'Open' ||
              complaint['status'] == 'Reverted');
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_checking_justification_permission")}: $e");
      }
      return false;
    }
  }

  Future<bool> canAcceptRejectJustification(String complaintId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final complaint = await _supabase
          .from('complaints')
          .select('user_id, status')
          .eq('id', complaintId)
          .maybeSingle();

      if (complaint == null) return false;

      return complaint['user_id'] == user.id &&
          complaint['status'] == 'Justified';
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_checking_accept_reject_permission")}: $e");
      }
      return false;
    }
  }

  Future<bool> canResolveComplaint() async {
    try {
      final role = await getUserRole();
      return role == 'truckowner' || role == 'company';
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_checking_resolve_permission")}: $e");
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getComplaintDetails(
      String complaintId) async {
    try {
      final complaint = await _supabase
          .from('complaints')
          .select('*')
          .eq('id', complaintId)
          .maybeSingle();

      return complaint;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_getting_complaint_details")}: $e");
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserComplaints() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final complaints = await _supabase
          .from('complaints')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(complaints);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_getting_user_complaints")}: $e");
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTargetComplaints() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final profile = await _supabase
          .from('user_profiles')
          .select('custom_user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final customUserId = profile?['custom_user_id'];
      if (customUserId == null) return [];

      final complaints = await _supabase
          .from('complaints')
          .select('*')
          .eq('target_user_id', customUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(complaints);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("${tr("error_getting_target_complaints")}: $e");
      }
      return [];
    }
  }
}
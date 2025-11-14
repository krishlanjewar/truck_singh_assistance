import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../service/rating_service.dart';

class Rating extends StatefulWidget {
  final String shipmentId;
  const Rating({super.key, required this.shipmentId});

  @override
  State<Rating> createState() => _RatingState();
}

class _RatingState extends State<Rating> {
  double ratingCreator = 0;
  double ratingDriver = 0;
  TextEditingController feedbackCreator = TextEditingController();
  TextEditingController feedbackDriver = TextEditingController();
  bool isLoading = true;

  final _client = Supabase.instance.client;
  final RatingService _ratingService = RatingService();

  String? creatorName;
  String? driverName;
  String? creatorId;
  String? driverId;
  String? raterRole;

  @override
  void initState() {
    super.initState();
    _fetchNames();
  }

  Future<void> _fetchNames() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception(tr("error_no_logged_in_user"));

      final currentProfile = await _client
          .from('user_profiles')
          .select('custom_user_id, role, name')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (currentProfile == null) throw Exception(tr("error_user_profile_not_found"));

      raterRole = currentProfile['role'] as String?;
      final raterId = currentProfile['custom_user_id'] as String?;

      if (raterId == null) throw Exception(tr("error_user_profile_not_found"));

      final shipment = await _client
          .from('shipment')
          .select('shipper_id, assigned_driver, assigned_agent')
          .eq('shipment_id', widget.shipmentId)
          .maybeSingle();

      if (shipment == null) throw Exception(tr("error_shipment_not_found"));

      creatorId = shipment['shipper_id'] as String? ?? shipment['assigned_agent'] as String?;
      driverId = shipment['assigned_driver'] as String?;

      if (creatorId != null) {
        final creatorProfile = await _client
            .from('user_profiles')
            .select('name')
            .eq('custom_user_id', creatorId ?? '') // now guaranteed non-null
            .maybeSingle();
        creatorName = creatorProfile?['name'] as String? ?? tr("default_creator");
      }

      if (driverId != null) {
        final driverProfile = await _client
            .from('user_profiles')
            .select('name')
            .eq('custom_user_id', driverId??'') // now guaranteed non-null
            .maybeSingle();
        driverName = driverProfile?['name'] as String? ?? tr("default_driver");
      }


      if (raterId != null) {
        final existingRatings = await _client
            .from('ratings')
            .select('ratee_id,rating,feedback')
            .eq('shipment_id', widget.shipmentId)
            .eq('rater_id', raterId);

        for (var r in existingRatings) {
          if (r['ratee_id'] == creatorId) {
            ratingCreator = (r['rating'] as num?)?.toDouble() ?? 0;
            feedbackCreator.text = r['feedback'] ?? '';
          } else if (r['ratee_id'] == driverId) {
            ratingDriver = (r['rating'] as num?)?.toDouble() ?? 0;
            feedbackDriver.text = r['feedback'] ?? '';
          }
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error fetching shipment names: $e");
      setState(() => isLoading = false);
    }
  }

  void _handleSubmitRating() async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception(tr("error_user_not_authenticated"));

      final profile = await _client
          .from('user_profiles')
          .select('custom_user_id, role')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (profile == null) throw Exception(tr("error_user_profile_not_found"));

      final raterId = profile['custom_user_id'] as String?;
      final raterRole = profile['role'] as String?;

      if (raterId == null || raterRole == null) throw Exception(tr("error_user_profile_not_found"));

      await _ratingService.submitRating(
        shipmentId: widget.shipmentId,
        raterId: raterId,
        raterRole: raterRole,
        ratingForCreator: ratingCreator,
        ratingForDriver: ratingDriver,
        feedbackCreator: feedbackCreator.text,
        feedbackDriver: feedbackDriver.text,
        creatorId: creatorId,
        driverId: driverId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("ratings_submitted_successfully"))),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr("error")}: $e')),
      );
    }
  }

  Widget buildShimmerSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        shimmerBox(height: 28, width: 200, margin: const EdgeInsets.only(bottom: 18)),
        shimmerBox(height: 60, width: double.infinity, margin: const EdgeInsets.only(bottom: 6)),
        const SizedBox(height: 10),
        shimmerBox(height: 20, width: 150, margin: const EdgeInsets.only(bottom: 8)),
        shimmerStars(),
        shimmerBox(height: 70, width: double.infinity, margin: const EdgeInsets.only(bottom: 24)),
        const SizedBox(height: 20),
        shimmerBox(height: 20, width: 150, margin: const EdgeInsets.only(bottom: 8)),
        shimmerStars(),
        shimmerBox(height: 70, width: double.infinity, margin: const EdgeInsets.only(bottom: 24)),
        const SizedBox(height: 10),
        shimmerBox(height: 48, width: double.infinity, margin: EdgeInsets.zero, borderRadius: 24),
      ],
    );
  }

  Widget shimmerBox({required double height, required double width, required EdgeInsets margin, double borderRadius = 8.0}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget shimmerStars() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: List.generate(5, (_) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: shimmerBox(height: 24, width: 24, margin: EdgeInsets.zero, borderRadius: 12),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    feedbackCreator.dispose();
    feedbackDriver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr("rate_shipment"))),
        body: buildShimmerSkeleton(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr("rate_shipment"))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${tr("hello")} ${creatorName ?? ''},", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (driverName != null) Text("${tr("assigned_driver")}: $driverName", style: const TextStyle(fontSize: 15)),
            const Divider(),
            const SizedBox(height: 20),
            if (creatorName != null) ...[
              Text("${tr("rate")} $creatorName", style: const TextStyle(fontSize: 16)),
              RatingBar.builder(
                initialRating: ratingCreator,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 30,
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) => setState(() => ratingCreator = rating),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: feedbackCreator,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr("feedback_for_creator"),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (driverName != null) ...[
              Text("${tr("rate")} $driverName", style: const TextStyle(fontSize: 16)),
              RatingBar.builder(
                initialRating: ratingDriver,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 30,
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (rating) => setState(() => ratingDriver = rating),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: feedbackDriver,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr("feedback_for_driver"),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
            ],
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleSubmitRating,
                icon: const Icon(Icons.send),
                label: Text(tr("submit_ratings")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
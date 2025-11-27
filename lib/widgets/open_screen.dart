import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logistics_toolkit/features/auth/services/supabase_service.dart';
import 'package:logistics_toolkit/features/driver_documents/driver_documents_page.dart';
import 'package:logistics_toolkit/features/laod_assignment/presentation/screen/allLoads.dart';
import 'package:logistics_toolkit/features/mytruck/mytrucks.dart';
import 'package:logistics_toolkit/features/tracking/tracktruckspage.dart';
import 'package:logistics_toolkit/features/trips/myTrips.dart';
import 'package:logistics_toolkit/features/trips/myTrips_history.dart';

import '../features/bilty/shipment_selection_page.dart';
import '../features/chat/agent_chat_list_page.dart';
import '../features/complains/mycomplain.dart';
import '../features/mydrivers/mydriver.dart';
import '../features/ratings/presentation/screen/trip_ratings.dart';
import '../features/tracking/shared_shipments_page.dart';
import '../features/truck_documents/truck_documents_page.dart';

Future<void> openScreen(String? screen, context, Map params) async {
  switch (screen) {
    case "my_shipments":
      Navigator.push(context, MaterialPageRoute(builder: (_) => MyShipments()));
      break;

    case "all_loads":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => allLoadsPage()),
      );
      break;

    case "shared_shipments":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SharedShipmentsPage()),
      );
      break;

    case "track_truck":
     // final truckOwnerIdList = params["truck_owner_id"];
     // final truckOwnerId = (truckOwnerIdList is List && truckOwnerIdList.isNotEmpty) ? truckOwnerIdList.first : null;
     //
     // if(truckOwnerId == null){
     //   print("truckOwnerId: $truckOwnerId is null");
     //   break;
     // }

       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (_) =>
               TrackTrucksPage(truckOwnerId: params["truck_owner_id"]),
         ),
       );

      break;

    case "my_trucks":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Mytrucks()),
      );
      break;

    case "my_drivers":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyDriverPage()),
      );
      break;

    case "truck_documents":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TruckDocumentsPage()),
      );
      break;

    case "driver_documents":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DriverDocumentsPage()),
      );
      break;

    case "my_trips":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MyTripsHistory()),
      );
      break;

    case "my_chats":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AgentChatListPage()),
      );
      break;

    case "bilty":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShipmentSelectionPage()),
      );
      break;

    case "ratings":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TripRatingsPage()),
      );
      break;

    case "complaints":
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ComplaintHistoryPage()),
      );
      break;
  }
}

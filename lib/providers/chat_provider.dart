
import 'package:flutter/cupertino.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logistics_toolkit/features/mytruck/mytrucks.dart';
import 'package:logistics_toolkit/services/gemini_service.dart';
import 'package:logistics_toolkit/services/intent_parser.dart';
import 'package:logistics_toolkit/services/shipment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? actionParameters;
  final String? actionButtonLabel;
  final String? actionButtonScreen;

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.actionParameters,
    this.actionButtonLabel,
    this.actionButtonScreen,
  });

  // ye tab kam ayega jab mereko chatmessage ko json me change krna hoga jaise ki gemini service me krra hu
  Map<String, dynamic> toJson() {
    return {
      "text": text,
      "isUser": isUser,
      "action": actionParameters?["action"],
      "language": actionParameters?["language"],
    };
  }
}

class ChatProvider extends ChangeNotifier {
  final GeminiService gemini;
  final SupabaseClient supabase;
  final FlutterTts _tts = FlutterTts();

  List<ChatMessage> messages = [];
  bool ttsEnabled = true;
  bool speaking = false;
  bool loading = false;

  ChatProvider({required this.gemini, required this.supabase}) {
    _tts.setStartHandler(() => speaking = true);
    _tts.setCompletionHandler(() {
      speaking = false;
      notifyListeners();
    });
    _tts.setErrorHandler((msg) {
      speaking = false;
      notifyListeners();
    });
  }

  void toggleTts() {
    ttsEnabled = !ttsEnabled;
    notifyListeners();
  }

  // add message in the chatList  from userChat
  void addUserMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: true));
    notifyListeners();
  }

  // add message in the chatList from chatBot model response
  void addBotMessage(ChatMessage msg) {
    messages.add(msg);
    notifyListeners();
    if (ttsEnabled)
      _speak(msg.text, msgActionLang: msg.actionParameters?['language']);
  }

  Future<void> _speak(String text, {String? msgActionLang}) async {
    try {
      final langCode = msgActionLang ?? 'en';
      await _tts.setLanguage(langCode);
      await _tts.speak(text);
    } catch (e) {
      print(e);
    }
  }

  Future<void> send(
    String input, {
    required void Function(String screen) onNavigate,
  }) async {
    addUserMessage(input);
    loading = true;
    notifyListeners();

    try {
      // isme messages jo hai history hai.
      final raw = await gemini.queryRaw(input, messages);
      final parsed = parseBotOutput(raw);

      //
      String replyText = parsed.reply.isNotEmpty
          ? parsed.reply
          : 'Reply received';
      Map<String, dynamic> params = parsed.parameters;

      // Decide if message should include an action button (open_screen)
      String? buttonLabel;
      String? buttonScreen;
      if (parsed.action == 'open_screen'){
        final screen = params['screen']?.toString() ?? '';

        if (screen.isNotEmpty) {
          buttonLabel = 'open ${screen}';
          buttonScreen = screen;
        }
      }

      //if the action requires a DB query, do it here
      switch (parsed.action) {
        //GET MARKETPLACE SHIPMENTS
        case 'get_marketplace_shipments':
          final list = await ShipmentService.getAvailableMarketplaceShipments();
          final market_place_shipments_ids = filterIdsByMap(list, "shipment_id");
          replyText = "${list.length} marketplace shipments available hain.\nMarket Place Shipments: ${market_place_shipments_ids.join(",")}";
          break;

        // agr fail ho gaya to kaise krenge handle abhi isliye stop
        // //ACCEPT MARKETPLACE SHIPMENTS
        //   case 'accept_marketplace_shipments':
        //     var  shipmentId = params["shipment_id"];
        //     await ShipmentService.acceptMarketplaceShipment(shipmentId: shipmentId) ;
        //     replyText = "marketplace shipments are accepted for shipment Id: $shipmentId }";
        //     break;
        //

        //GET ACTIVE SHIPMENTS
        case 'get_active_shipments':
          final response = await ShipmentService.getAllMyShipments();
          final count = (response as List).length;
          final active_shipment_ids = filterIdsByMap(response, 'shipment_id');
          replyText = 'Aapki $count shipments abhi active hain.\nActive Shipments IDs: ${active_shipment_ids.join(",")}';
          break;

        //GET SHIPMENTS BY STATUS
        case 'get_shipments_by_status':
          final response = ShipmentService.getShipmentsByStatus(
            statuses: params["status"],
          );
          final count = (response as List).length;
          // final json = jsonEncode( response);
          var shipment_ids = filterIdsByMap(await response , "shipment_id");
          replyText = 'Aapki $count shipments ${params["status"]} hain.\nShipment IDs: ${shipment_ids.join(",")}';
          break;

        //GET AVAILABLE TRUCKS
        case 'get_available_trucks':
          final res = await supabase
              .from('trucks')
              .select()
              .eq('status', 'available');
          final count = (res as List).length;
          final truck_numbers = filterIdsByMap(res, "truck_number");
          replyText = '$count trucks abhi khali hain.\nTrucks Number:${truck_numbers.join(",")}';
          break;

        //GET AVAILABLE TRUCKS
        case 'get_on_trip_trucks':
          final res = await supabase
              .from('trucks')
              .select()
              .eq('status', 'on_trip');
          final count = (res as List).length;
          replyText = '$count trucks abhi trip pr hain.';
          break;

        //GET COMPLETED SHIPMENTS
        case 'get_completed_shipments':
          final response = await ShipmentService.getAllMyCompletedShipments();
          final completed = (response as List).length;
          replyText = 'Aapke $completed shipments complete ho chuke hain.';
          break;

        //GET DRIVER DETAILS BY DRIVER_ID
        case 'get_driver_details':
          final driverId = params['driver_id']?.toString();
          if (driverId != null && driverId.isNotEmpty) {
            final res = await supabase
                .from('drivers')
                .select()
                .eq('id', driverId)
                .maybeSingle();
            if (res == null)
              replyText = 'Driver not found.';
            else
              replyText =
                  'Driver ${res['name']}, phone: ${res['phone'] ?? 'N/A'}';
          } else {
            replyText = 'Driver id missing.';
          }
          break;

        case 'get_status_by_shipment_id':
          final ids = params['shipment_id'];

          if (ids == null || ids.isEmpty) {
            replyText = "Shipment ID batao.";
            break;
          }

          final shipmentId = ids.first.toString();

          try {
            final status = await ShipmentService.getStatusByShipmentId(
              shipmentId: shipmentId,
            );

            if (status == null) {
              replyText = "$shipmentId ka koi status nahi mila.";
            } else {
              replyText = "$shipmentId ka status: $status hai.";
            }
          } catch (e) {
            replyText = "Status fetch karne me error aaya.";
          }
          break;




        case 'open_screen':
          final screen = params['screen']?.toString() ?? '';
          replyText = parsed.reply.isNotEmpty
              ? parsed.reply
              : 'Opening $screen';
          if (screen.isNotEmpty) {
            // include navigation button in message; also call onNavigate optionally
            buttonLabel = 'Go to $screen';
            buttonScreen = screen;
          }
          break;
        default:
          // unknown: model may already have included a helpful reply
          break;
      }

      addBotMessage(
        ChatMessage(
          text: replyText,
          isUser: false,
          actionParameters: {
            'language': parsed.language,
            'action': parsed.action,
          },
          actionButtonLabel: buttonLabel,
          actionButtonScreen: buttonScreen,
        ),
      );

      // If action is open_screen, also auto-navigate (optional). We'll not auto-navigate to avoid surprising user.
      // If you want auto navigation uncomment next lines:
      // if (parsed.action == 'open_screen' && buttonScreen != null) {
      //   onNavigate(buttonScreen);
      // }
    } catch (e) {
      addBotMessage(
        ChatMessage(text: 'Service error: ${e.toString()}', isUser: false),
      );
      print(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

List<String> filterIdsByMap(List<Map<String, dynamic>> shipments, String key) {
  return shipments
      .map((map) => map[key].toString() ?? "")
      .where((id) => id.isNotEmpty)
      .toList();
}

//
// List<Map<String, dynamic>> filterShipments(
//     List<Map<String, dynamic>> shipments,
//     ) {
//   return shipments.map((map) {
//     return {
//       for (final key in shipment_map_keys)
//         if (map.containsKey(key)) key: map[key],
//     };
//   }).toList();
// }
//
//
//
// final shipment_map_keys = [
//   'shipment_id',
//   'shipper_id',
//   'pickup',
//   'drop',
//   'pickup_latitude',
//   'pickup_longitude',
//   'dropoff_latitude',
//   'dropoff_longitude',
//   'shipping_item',
//   'weight',
//   'unit',
//   'delivery_date',
//   'pickup_date',
//   'material_inside',
//   'truck_type',
//   'pickup_time',
//   'notes',
//   'booking_status',
//   'assigned_company',
// ];

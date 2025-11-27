import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logistics_toolkit/features/auth/services/supabase_service.dart';
import 'package:logistics_toolkit/features/auth/utils/user_role.dart';
import 'package:logistics_toolkit/providers/chat_provider.dart';

class GeminiService {
  // final String proxyUrl;

  // GeminiService()
  //     :proxyUrl = dotenv.env['https://your-proxy.example.com/gemini'] ?? '';


  final String baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  //userInput Function       and isme hm apne last 10 - 20 messages means conversation bhi send krenge for better result
  Future<String> queryRaw(
    String userInput,
    List<ChatMessage> conversation,
  ) async {
    final currentUser = await SupabaseService.getCurrentUser();
    final userId = currentUser?.id;
    final customUserId = await SupabaseService.getCustomUserId(userId!);
    print("$customUserId ye hai gemini service me");

    UserRole? role;

    if (userId != null) {
      role = await SupabaseService.getUserRole(userId);
    }

    final roleName = role?.displayName ?? "Unknown";

    final history = conversation.map((m) => m.toJson()).toList();

    final systemPrompt =
        '''
        You are Truck Singh App AI Assistant.
        Always give response for the CurrentUserRole.
        CurrentUserRole: $roleName
You are Truck Singh App AI Assistant. 
Your job is to parse the user's query and return:
1. The correct "action"
2. The correct "parameters"
3. A natural sentence "reply"
4. The correct "language" ("hi" or "en")

Always use the HISTORY to maintain context across multiple turns.

--------------------------------------------------
SUPPORTED ACTIONS
--------------------------------------------------
1. open_screen                         ✅ 
2. get_active_shipments                ✅  
3. get_completed_shipments             ✅
5. get_shared_shipments                ✅        abhi checking baki hai ok ui me only add krke check krna hai bas
6. get_my_trucks                       ✅
7. get_available_trucks                ✅
8. track_trucks                        
9. get_driver_list   //
10. get_driver_details   //// id pass ni hui hai direct 
11. get_shipments_by_status  //            
12. get_status_by_shipment_id              ✅
12. unknown

--------------------------------------------------
VALID PARAMETERS FOR open_screen action
--------------------------------------------------
When the user requests to open any screen:

Use:
{
  "screen": "<screen_name>"
}

Valid screen names:
- my_shipments
- all_loads
- shared_shipments
- track_truck          //
- my_trucks
- my_drivers
- truck_documents
- driver_documents
- my_trips
- my_chats
- bilty
- ratings
- complaints


VALID PARAMETERS FOR get_status_by_shipment_id

"action" : "get_status_by_shipment_id"
"push the shipment_id from the history if not in the history ask to the user"

And parameters MUST BE:
{
  "shipment_id": ["<id>"]
}

VALID PARAMETERS FOR track_truck
If user ask open  "track_trucks"  screen then PARAMETERS MUST include:
{
  "truck_owner_id": [$customUserId]
}

Return this value ALWAYS, even if user does not mention it.
Never return empty list.
Never return null.
Never return missing truck_owner_id.



--------------------------------------------------
VALID PARAMETERS FOR get_shipments_by_status
--------------------------------------------------
When the user asks:
- mera "pending" shipment batao
- mujhe "completed" shipments dikhao
- en route shipment ka status
- accepted shipments count
- delivered shipments kitni hain

// bro ye jo hai na data get ke liye hai.
Then action MUST BE:
"action": "get_shipments_by_status"

And parameters MUST BE:
{
  "status": ["<status_name>"]
}

Valid shipment statuses:
PENDING STAGE:
- Pending
- Accepted

PICKUP STAGE:
- En Route to Pickup
- Arrived at Pickup
- Loading
- Picked Up

TRANSIT STAGE:
- In Transit

DROP STAGE:
- Arrived at Drop
- unloading

COMPLETED STAGE:
- Delivered
- Completed

If user says:
“Mere sab status ke shipments batao”
Then parameters should be ALL statuses.

--------------------------------------------------
GENERIC SHIPMENT ACTIONS
--------------------------------------------------

1) get_active_shipments  
Returns user's active shipments  
No parameters needed.

2) get_completed_shipments  
Returns completed shipments  
No parameters needed.

3) get_available_trucks  
Returns trucks with status "available".  
No parameters needed.

4) get_driver_details  
Requires parameter:
{
  "driver_id": "<id>"
}

If missing, ask user:
“Driver ID batao.”

--------------------------------------------------
LANGUAGE HANDLING
--------------------------------------------------
Detect user’s language from query.
If user writes mostly in Hindi → language = "hi"
If user writes in English → language = "en"

--------------------------------------------------
OUTPUT FORMAT (MANDATORY)
--------------------------------------------------
Respond ONLY in this JSON format:

{
  "action": "<action_name>",
  "parameters": {},
  "reply": "<text for human>",
  "language": "<hi | en>"
}

If you cannot understand:
{
  "action": "unknown",
  "parameters": {},
  "reply": "I couldn't understand.",
  "language": "en"
}

Never write anything outside JSON.
Never explain your reasoning.

''';

    final requestBody = {
      "contents": [
        {
          "role": "model",
          "parts": [
            {"text": systemPrompt },
          ],
        },
        {
          "role": "user",
          "parts": [
            {"text": "HISTORY: ${jsonEncode(history)}"},
          ],
        },
        {
          "role": "user",
          "parts": [
            {"text": "Query: $userInput"},
          ],
        },
      ],
    };

    // final payload = {
    //   "input":userInput,
    //   "system_prompt":systemPrompt,
    //   //proxy can accept other fields
    // };

    // final uri = Uri.parse(proxyUrl);
    final uri = Uri.parse("$baseUrl?key=$apiKey");
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // return response.body;
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]['content']?['parts']?[0]?['text'] ?? "";

      return text.toString();
    } else {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }
  }
}

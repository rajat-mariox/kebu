import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class SupportApiService {
  /// POST /driver/app/support/tickets
  static Future<ApiResponse> createSupportTicket({
    String subject = 'Driver Support',
    String description = 'Driver needs assistance',
    String category = 'OTHER',
  }) async {
    return await ApiClient.post('/driver/app/support/tickets', body: {
      'subject': subject,
      'description': description,
      'category': category,
    });
  }

  /// GET /driver/app/support/tickets
  static Future<ApiResponse> getSupportTickets() async {
    return await ApiClient.get('/driver/app/support/tickets');
  }

  /// POST /driver/app/support/tickets/:ticketId/message
  static Future<ApiResponse> addTicketMessage(String ticketId, String message) async {
    return await ApiClient.post('/driver/app/support/tickets/$ticketId/message', body: {
      'message': message,
    });
  }
}

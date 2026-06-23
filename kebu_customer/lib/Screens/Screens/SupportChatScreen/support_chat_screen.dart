import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/socket_service.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];

  String? _ticketId;
  bool _loading = true;
  bool _isBotMode = true;
  bool _isTyping = false;
  String _supportAgentName = 'Kebu Support';
  StreamSubscription? _supportMessageSub;

  // Chatbot FAQ responses
  static final Map<String, String> _botResponses = {
    'booking': 'You can book a ride from the home screen by tapping "Book a Ride". Select your pickup and drop location, choose a vehicle type, and tap "Book Now".',
    'cancel': 'To cancel a booking, go to the live tracking screen and tap the cancel button. Note that cancellation charges may apply if a driver has already been assigned.',
    'payment': 'We accept Cash and UPI payments. You can select your preferred payment method while booking a ride.',
    'driver': 'Once a driver is assigned, you can see their details including name, vehicle number, and live location on the tracking screen.',
    'refund': 'Refunds are processed within 5-7 business days to your original payment method. If you have not received your refund, please share your booking ID.',
    'account': 'You can update your profile from the Accounts tab. Tap on your profile to edit your name, email, or profile picture.',
    'pricing': 'Our pricing is based on distance, vehicle type, and demand. You can see the fare estimate before confirming your booking.',
    'safety': 'Your safety is our priority. Every ride includes SOS emergency button, ride sharing with contacts, and driver verification.',
    'contact': 'You can reach us through this chat, email at support@kebu.com, or call our 24x7 helpline.',
  };

  static const List<String> _quickReplies = [
    'Booking issue',
    'Payment help',
    'Cancel ride',
    'Refund status',
    'Driver issue',
    'Account help',
  ];

  @override
  void initState() {
    super.initState();
    _initChat();
    _listenToSupportMessages();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _supportMessageSub?.cancel();
    super.dispose();
  }

  void _listenToSupportMessages() {
    final socket = SocketService();
    socket.connect();

    _supportMessageSub = socket.onNotification.listen((data) {
      if (data['type'] == 'support_message' && mounted) {
        final msg = data['message']?.toString() ?? '';
        final sender = data['senderName']?.toString() ?? 'Support Agent';
        if (msg.isNotEmpty) {
          setState(() {
            _isBotMode = false;
            _supportAgentName = sender;
            _messages.add(ChatMessage(
              text: msg,
              isUser: false,
              time: DateTime.now(),
              senderName: sender,
            ));
          });
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _initChat() async {
    // Load existing tickets or create initial bot greeting
    final response = await CustomerFeaturesApiService.getSupportTickets();

    if (mounted) {
      setState(() {
        _loading = false;

        // Check if there's an open ticket with messages
        if (response.success && response.data != null) {
          final tickets = response.data['tickets'] as List? ?? [];
          final openTicket = tickets.firstWhere(
            (t) => t['status'] == 'OPEN' || t['status'] == 'IN_PROGRESS',
            orElse: () => null,
          );

          if (openTicket != null) {
            _ticketId = openTicket['_id']?.toString();
            final isAssigned = openTicket['assignedTo'] != null;
            _isBotMode = !isAssigned;
            if (isAssigned) {
              _supportAgentName = openTicket['assignedTo']?['name']?.toString() ?? 'Support Agent';
            }

            // Load existing messages
            final msgs = openTicket['messages'] as List? ?? [];
            for (final m in msgs) {
              _messages.add(ChatMessage(
                text: m['message']?.toString() ?? '',
                isUser: m['senderType'] == 'USER',
                time: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
                senderName: m['senderType'] == 'USER' ? 'You' : _supportAgentName,
              ));
            }
          }
        }

        // Add bot greeting if no messages
        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            text: 'Hello! Welcome to Kebu Support. How can I help you today?',
            isUser: false,
            time: DateTime.now(),
            senderName: 'Kebu Bot',
          ));
          _messages.add(ChatMessage(
            text: 'You can ask me about bookings, payments, cancellations, refunds, or any other issue. Or tap a quick reply below!',
            isUser: false,
            time: DateTime.now(),
            senderName: 'Kebu Bot',
          ));
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _messageCtrl.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: text.trim(),
        isUser: true,
        time: DateTime.now(),
        senderName: 'You',
      ));
    });
    _scrollToBottom();

    if (_isBotMode) {
      _handleBotResponse(text.trim());
    } else {
      // Send to real support via API
      await _sendToSupport(text.trim());
    }
  }

  void _handleBotResponse(String userMessage) {
    setState(() => _isTyping = true);
    _scrollToBottom();

    // Simulate typing delay
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      final lowerMsg = userMessage.toLowerCase();
      String? botReply;

      // Match against keywords
      for (final entry in _botResponses.entries) {
        if (lowerMsg.contains(entry.key)) {
          botReply = entry.value;
          break;
        }
      }

      // Check for common greetings
      if (botReply == null) {
        final greetings = ['hi', 'hello', 'hey', 'good morning', 'good evening'];
        if (greetings.any((g) => lowerMsg.contains(g))) {
          botReply = 'Hello! How can I assist you today? Feel free to ask about bookings, payments, or any issue.';
        }
      }

      // Check for "talk to agent" / "human" / "support"
      if (lowerMsg.contains('agent') || lowerMsg.contains('human') || lowerMsg.contains('real person') || lowerMsg.contains('talk to')) {
        _connectToAgent(userMessage);
        return;
      }

      // Fallback
      botReply ??= 'I\'m not sure about that. Would you like to talk to a support agent? Just type "talk to agent" and I\'ll connect you right away!';

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: botReply!,
          isUser: false,
          time: DateTime.now(),
          senderName: 'Kebu Bot',
        ));
      });
      _scrollToBottom();
    });
  }

  Future<void> _connectToAgent(String lastMessage) async {
    setState(() => _isTyping = true);

    // Create a support ticket if none exists
    if (_ticketId == null) {
      final response = await CustomerFeaturesApiService.createSupportTicket(
        subject: 'Live Chat Support',
        description: lastMessage,
        category: 'OTHER',
      );

      if (response.success && response.data != null) {
        final ticket = response.data['ticket'] ?? response.data;
        _ticketId = ticket['_id']?.toString();
      }
    }

    // Notify via socket that user needs support
    final socket = SocketService();
    socket.emit('support_request', {
      'ticketId': _ticketId,
      'userId': Prefs.user_id,
      'message': lastMessage,
    });

    if (mounted) {
      setState(() {
        _isTyping = false;
        _isBotMode = false;
        _messages.add(ChatMessage(
          text: 'Connecting you to a support agent... Please wait, someone will be with you shortly.',
          isUser: false,
          time: DateTime.now(),
          senderName: 'Kebu Bot',
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendToSupport(String message) async {
    if (_ticketId == null) {
      // Create ticket first
      final response = await CustomerFeaturesApiService.createSupportTicket(
        subject: 'Live Chat Support',
        description: message,
      );
      if (response.success && response.data != null) {
        final ticket = response.data['ticket'] ?? response.data;
        _ticketId = ticket['_id']?.toString();
      }
    } else {
      await CustomerFeaturesApiService.addTicketMessage(_ticketId!, message);
    }

    // Also emit via socket for real-time delivery
    final socket = SocketService();
    socket.emit('support_message', {
      'ticketId': _ticketId,
      'userId': Prefs.user_id,
      'message': message,
      'senderType': 'USER',
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HexColor("#FFD546"), HexColor("#FF155E")],
          ),
        ),
        child: Column(
          children: [
            // ── App Bar ──
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                    ),
                    Expanded(
                      child: Text(
                        'Support Chat',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 24),
                  ],
                ),
              ),
            ),

            // ── Chat Content ──
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    // ── Header section ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 28, 30, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Chat',
                            style: GoogleFonts.dmSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.4,
                              color: HexColor("#040415"),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please wait our support team will reply you as soon as possible.',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              height: 1.6,
                              letterSpacing: -0.35,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Agent info (always shown) ──
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x1A000000)),
                          bottom: BorderSide(color: Color(0x1A000000)),
                        ),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      HexColor("#FFD546"),
                                      HexColor("#FF155E")
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _supportAgentName.isNotEmpty
                                      ? _supportAgentName
                                          .trim()
                                          .split(' ')
                                          .map((e) => e.isNotEmpty ? e[0] : '')
                                          .take(2)
                                          .join()
                                          .toUpperCase()
                                      : 'KS',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: HexColor("#4FBF67"),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _supportAgentName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: HexColor("#1B1D21"),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isBotMode ? 'Online' : 'Active now',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: HexColor("#D9D9D9"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Messages list ──
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              itemCount: _messages.length + (_isTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _messages.length && _isTyping) {
                                  return _buildTypingIndicator();
                                }
                                return _buildMessageBubble(_messages[index]);
                              },
                            ),
                    ),

                    // ── Quick replies (bot mode only) ──
                    if (_isBotMode && _messages.length <= 3)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _quickReplies.map((reply) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _sendMessage(reply),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: HexColor("#FFD546")),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    reply,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: HexColor("#333333"),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // ── Input bar ──
                    Container(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding + 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined,
                              color: HexColor("#1B1D21"), size: 24),
                          const SizedBox(width: 14),
                          Icon(Icons.mic_none_rounded,
                              color: HexColor("#1B1D21"), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageCtrl,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 14, letterSpacing: -0.3),
                                      decoration: InputDecoration(
                                        hintText: 'Aa',
                                        hintStyle: GoogleFonts.dmSans(
                                            color: HexColor("#999999"),
                                            fontSize: 14),
                                        border: InputBorder.none,
                                        isCollapsed: true,
                                      ),
                                      onSubmitted: _sendMessage,
                                    ),
                                  ),
                                  Icon(Icons.emoji_emotions_outlined,
                                      color: HexColor("#1B1D21"), size: 22),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _sendMessage(_messageCtrl.text),
                            child: Transform.rotate(
                              angle: -0.785398,
                              child: Icon(Icons.send,
                                  color: HexColor("#1B1D21"), size: 26),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final hour12 = msg.time.hour % 12 == 0 ? 12 : msg.time.hour % 12;
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')} ${msg.time.hour >= 12 ? 'PM' : 'AM'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [HexColor("#FFD546"), HexColor("#FF155E")],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isUser ? null : HexColor("#1B1D21").withOpacity(0.04),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: Radius.circular(isUser ? 24 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 24),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      letterSpacing: -0.3,
                      height: 1.5,
                      color: isUser ? Colors.white : HexColor("#1B1D21"),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Text(
              timeStr,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                letterSpacing: -0.25,
                color: HexColor("#1B1D21").withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: HexColor("#1B1D21").withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + (i * 200)),
                  builder: (context, value, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400.withOpacity(0.4 + (value * 0.6)),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final String senderName;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.senderName = '',
  });
}

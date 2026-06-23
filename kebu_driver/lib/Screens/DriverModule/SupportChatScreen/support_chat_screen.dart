import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Services/support_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

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

  static final Map<String, String> _botResponses = {
    'onboarding': 'Your onboarding is under review by our team. We will verify your documents and approve your account soon. This usually takes 24-48 hours.',
    'document': 'If you need to update any documents, please go back to the onboarding screens and re-upload them. Make sure all images are clear and readable.',
    'verify': 'Our team reviews all documents manually for safety. If approved, you will be able to access the home screen and start accepting rides.',
    'reject': 'If your application was rejected, you should have received a reason. Please correct the issue and re-submit your documents.',
    'time': 'Verification usually takes 24-48 hours. During peak times, it may take a bit longer. Thank you for your patience!',
    'payment': 'Payment details are verified along with your other documents. Make sure your bank account number and IFSC code are correct.',
    'licence': 'Please ensure your driving licence is valid and not expired. Upload clear front and back images.',
    'aadhar': 'Your Aadhaar card must be valid and the number should be 12 digits. Make sure both front and back images are clear.',
    'pan': 'Your PAN card must follow the format ABCDE1234F. Upload a clear front image.',
    'contact': 'You can reach us through this chat or email at support@kebu.com. Our team is available 24x7.',
  };

  static const List<String> _quickReplies = [
    'Verification status',
    'Document issue',
    'How long to verify?',
    'Payment help',
    'Talk to agent',
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
    final response = await SupportApiService.getSupportTickets();

    if (mounted) {
      setState(() {
        _loading = false;

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

            final msgs = openTicket['messages'] as List? ?? [];
            for (final m in msgs) {
              _messages.add(ChatMessage(
                text: m['message']?.toString() ?? '',
                isUser: m['senderType'] == 'DRIVER',
                time: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
                senderName: m['senderType'] == 'DRIVER' ? 'You' : _supportAgentName,
              ));
            }
          }
        }

        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            text: 'Hello! Welcome to Kebu Driver Support. How can I help you today?',
            isUser: false,
            time: DateTime.now(),
            senderName: 'Kebu Bot',
          ));
          _messages.add(ChatMessage(
            text: 'You can ask me about verification status, documents, payments, or any issue. Or tap a quick reply below!',
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
      await _sendToSupport(text.trim());
    }
  }

  void _handleBotResponse(String userMessage) {
    setState(() => _isTyping = true);
    _scrollToBottom();

    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      final lowerMsg = userMessage.toLowerCase();
      String? botReply;

      for (final entry in _botResponses.entries) {
        if (lowerMsg.contains(entry.key)) {
          botReply = entry.value;
          break;
        }
      }

      if (botReply == null) {
        final greetings = ['hi', 'hello', 'hey', 'good morning', 'good evening'];
        if (greetings.any((g) => lowerMsg.contains(g))) {
          botReply = 'Hello! How can I assist you today? Feel free to ask about verification, documents, or any issue.';
        }
      }

      if (lowerMsg.contains('agent') || lowerMsg.contains('human') || lowerMsg.contains('real person') || lowerMsg.contains('talk to')) {
        _connectToAgent(userMessage);
        return;
      }

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

    if (_ticketId == null) {
      final response = await SupportApiService.createSupportTicket(
        subject: 'Driver Support Chat',
        description: lastMessage,
        category: 'OTHER',
      );

      if (response.success && response.data != null) {
        final ticket = response.data['ticket'] ?? response.data;
        _ticketId = ticket['_id']?.toString();
      }
    }

    final socket = SocketService();
    socket.emit('support_request', {
      'ticketId': _ticketId,
      'driverId': Prefs.user_id,
      'message': lastMessage,
      'senderType': 'DRIVER',
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
      final response = await SupportApiService.createSupportTicket(
        subject: 'Driver Support Chat',
        description: message,
      );
      if (response.success && response.data != null) {
        final ticket = response.data['ticket'] ?? response.data;
        _ticketId = ticket['_id']?.toString();
      }
    } else {
      await SupportApiService.addTicketMessage(_ticketId!, message);
    }

    final socket = SocketService();
    socket.emit('support_message', {
      'ticketId': _ticketId,
      'driverId': Prefs.user_id,
      'message': message,
      'senderType': 'DRIVER',
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        color: HexColor("#A2BF49"),
        child: Column(
          children: [
            // App Bar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Support Chat',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // Chat Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Chat',
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isBotMode
                                ? 'Chat with our bot or ask to talk to an agent'
                                : 'Connected with $_supportAgentName',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Agent info
                    if (!_isBotMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: HexColor("#A2BF49"),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _supportAgentName.isNotEmpty ? _supportAgentName[0].toUpperCase() : 'S',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _supportAgentName,
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Active now',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const Divider(height: 1),

                    // Messages list
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

                    // Quick replies
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
                                    border: Border.all(color: HexColor("#A2BF49")),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    reply,
                                    style: GoogleFonts.nunito(
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

                    // Input bar
                    Container(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding + 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _messageCtrl,
                                style: GoogleFonts.nunito(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onSubmitted: _sendMessage,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _sendMessage(_messageCtrl.text),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: HexColor("#A2BF49"),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send, color: Colors.white, size: 20),
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
    final hour = msg.time.hour;
    final minute = msg.time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr = '$displayHour:$minute $period';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: HexColor("#A2BF49"),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'K',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? HexColor("#A2BF49") : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 36,
            ),
            child: Text(
              timeStr,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: HexColor("#A2BF49"),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('K', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
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
                        color: Colors.grey.shade400.withAlpha((102 + (value * 153)).toInt()),
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

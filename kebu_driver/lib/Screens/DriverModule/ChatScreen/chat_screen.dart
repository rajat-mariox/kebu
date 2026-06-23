import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
       )
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [

          commonAppBar(
              height : 100,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 47),
                child: Row(
                  children: [
                    const SizedBox(width: 5,),
                    Row(
                      children: [
                        InkWell(
                          onTap: (){
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.only(left: 16),
                            width: 40,
                            height: 35,
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_back_ios, color: Colors.white,),
                          ),
                        ),
                        const Text(
                          "Shubham Singh",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
          ),


          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _ChatBubble(
                  text: "Hello, good morning Andrew",
                  isMe: false,
                  time: "09:41",
                ),
                _ChatBubble(
                  text: "I'm Theo, I'm on my way to your location. Please wait... ⏳😄",
                  isMe: false,
                  time: "09:41",
                ),
                _ChatBubble(
                  text:
                  "Hello Theo, ok I will be waiting for you in front of Bobst Library.  You can contact me as soon as possible when you arrive",
                  isMe: true,
                  time: "09:41",
                ),
                _ImageBubble(
                  imageUrls: [
                    'assets/chat_1.jpeg', // replace with actual image URLs
                    'assets/chat_2.jpeg',
                  ],
                ),
                _ChatBubble(
                  text: "Great! I'll be there in less than 1 minute 🔥",
                  isMe: false,
                  time: "09:41",
                ),
                _ChatBubble(
                  text: "Okay! Great",
                  isMe: true,
                  time: "09:41",
                ),
              ],
            ),
          ),

          // Message Input
          const _ChatInput(),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isMe ? HexColor("#A2BF49") : const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final List<String> imageUrls;

  const _ImageBubble({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: imageUrls
              .map((url) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(url, fit: BoxFit.cover,)
            ),
          ))
              .toList(),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.3),
        ),
        color: Colors.white,
      ),
      child: Row(
        children: [

          const SizedBox(width: 5,),

          Container(
            child: const Icon(Icons.emoji_emotions_outlined,),
          ),

          const SizedBox(width: 9,),

          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Send a message...",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),

          Transform.rotate(
            angle: 0.5,
            child: IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: () {},
            ),
          ),

          Transform.rotate(
            angle: 5.5,
            child: Container(
              padding: const EdgeInsets.only(left: 10, right: 7, bottom: 10, top: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HexColor("#A2BF49"),
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),

          const SizedBox(width: 5,)

        ],
      ),
    );
  }
}

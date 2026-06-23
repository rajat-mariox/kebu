import 'package:flutter/material.dart';


Widget editTextWidget({
  required BuildContext context,
  required TextEditingController controller,
  required String hintText,
  required bool isOptional,
  required String labelText,
   Widget? suffixIcon
}){
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 3,),
          Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: Text(labelText, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),)
          ),

          if(isOptional == false)
          Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),)
          ),
        ],
      ),

      Container(
        height: 50,
        padding: const EdgeInsets.only(left: 15, right: 15),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color : Colors.grey.shade300)
        ),
        child: Center(
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.black, fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle:  const TextStyle(color: Colors.grey, fontSize: 13),
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              suffixIconConstraints: const BoxConstraints(
                maxWidth: 30
              ),
              suffixIcon: suffixIcon
            ),
          ),
        ),
      ),
    ],
  );
}
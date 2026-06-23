import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

  Widget onBoardingProgressWidget(){
    return Container(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                margin: const EdgeInsets.only(left: 15),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: HexColor("#848484",), width: 1)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: HexColor("#848484"),
                  ),
                ),
              ),

              Expanded(
                  child: Container(
                    height: 1,
                    color: HexColor("#848484"),)
              ),


              Container(
                height: 32,
                width: 32,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HexColor("#848484",), width: 1)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: HexColor("#848484"),
                  ),
                ),
              ),

              Expanded(
                  child: Container(
                    height: 1,
                    color: HexColor("#848484"),)
              ),

              Container(
                height: 32,
                width: 32,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HexColor("#848484",), width: 1)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: HexColor("#848484"),
                  ),
                ),
              ),

              Expanded(
                  child: Container(
                    height: 1,
                    color: HexColor("#848484"),)
              ),

              Container(
                height: 32,
                width: 32,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HexColor("#848484",), width: 1)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: HexColor("#848484"),
                  ),
                ),
              ),

              Expanded(
                  child: Container(
                  height: 1,
                  color: HexColor("#848484"),)
              ),


              Container(
                height: 32,
                width: 32,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HexColor("#848484",), width: 1)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: HexColor("#848484"),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10,),

          Row(
            children: [

              const SizedBox(width: 10,),

              Text("Basic Details", style: TextStyle(color: HexColor("#848484"), fontSize: 12),),

              Expanded(child: Center(
                child: Text("DL Details", style: TextStyle(color: HexColor("#848484"), fontSize: 12)
                  ,),
              )
              ),

              Expanded(child: Center(
                child: Text("Documents", style: TextStyle(color: HexColor("#848484"), fontSize: 12)
                  ,),
                )
              ),

              Text("Address", style: TextStyle(color: HexColor("#848484"), fontSize: 12),),


              Text("Bank", style: TextStyle(color: HexColor("#848484"), fontSize: 12)
                ,),

              const SizedBox(width: 10,),
            ],
          )
        ],
      ),
    );
  }
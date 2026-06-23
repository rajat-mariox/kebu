import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:flutter/material.dart';


class ReceivedAmount extends StatefulWidget {
  const ReceivedAmount({super.key});

  @override
  State<ReceivedAmount> createState() => _ReceivedAmountState();
}

class _ReceivedAmountState extends State<ReceivedAmount> {
  final List<TransactionItem> transactions = [
    TransactionItem("Your Earning", "C079DB3D", 873.01),
    TransactionItem("Refund - Trip Issue", "C079DB3D-refund-C079DB3D", 873.01),
    TransactionItem("Your Earning", "C079DB3D", 873.01),
    TransactionItem("Refund - Trip Issue", "C079DB3D-refund-C079DB3D", 873.01),
    TransactionItem("Your Earning", "C079DB3D", 873.01),
    TransactionItem("Refund - Trip Issue", "C079DB3D-refund-C079DB3D", 873.01),
    TransactionItem("Your Earning", "C079DB3D", 873.01),
    TransactionItem("Refund - Trip Issue", "C079DB3D-refund-C079DB3D", 873.01),
    TransactionItem("Your Earning", "C079DB3D", 873.01),
    TransactionItem("Refund - Trip Issue", "C079DB3D-refund-C079DB3D", 873.01),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
                height : 100,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: ()
                        {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.only(left: 16),
                          width: 40,
                          height: 35,
                          alignment: Alignment.center,
                          child: Image.asset("assets/back_arrow.png", color: Colors.black,),
                        ),
                      ),

                      const SizedBox(width: 8,),

                      const Text(
                        "Received Amount",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                    ],
                  ),
                )
            ),

            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 8),
              child: Row(children: <Widget>[
                const Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "JANUARY 2024",
                    style: TextStyle(fontWeight: FontWeight.bold,fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                const Expanded(child: Divider(thickness: 1)),
              ]),
            ),
            Container(height: 8, color: Colors.white,),
            Container(
              color: Colors.white,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 0),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  return _buildTransactionTile(transactions[index]);
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2575FC), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Top balance section
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                Text("Total balance", style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text("₹2,430.00",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Action icons
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [

                _buildActionItem('assets/rechage_amount.png', "Recharge\nWallet"),
                _buildActionItem('assets/send_amount.png', "Wallet\nStatement"),
                _buildActionItem('assets/statement.png', "Send\nAmount"),
                _buildActionItem('assets/recieve_amount.png', "Received\nAmount"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String icon, String label) {
    return Column(
      children: [
        Image.asset(icon, height: 40,),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionItem item) {
    bool isCredit = item.amount > 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Reference ID: ${item.referenceId}", style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                  const SizedBox(height: 6),
                ],
              ),

              const Spacer(),

              Text(
                "${isCredit ? '+' : '-'} ₹${item.amount.abs().toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              )
            ],
          ),
        ),

        Container(
          height: 0.5,
          width: MediaQuery.of(context).size.width,
          color: Colors.grey[400],
        )
      ],
    );
  }
}

class TransactionItem {
  final String title;
  final String referenceId;
  final double amount;

  TransactionItem(this.title, this.referenceId, this.amount);
}

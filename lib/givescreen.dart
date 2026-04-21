import 'package:flutter/material.dart';


class GiveCollectPage extends StatelessWidget {
  const GiveCollectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // TITLE + BACK
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Package Tracking",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Back"),
                  )
                ],
              ),

              const SizedBox(height: 10),

              // GIVE / COLLECT TOGGLE
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    onPressed: () {},
                    child: const Text("Give"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Collect"),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // BATCH TABS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    batchTab("Batch A", true),
                    batchTab("Batch B", false),
                    batchTab("Batch C", false),
                    batchTab("Batch D", false),
                    batchTab("Batch E", false),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // SEARCH ITEMS
              TextField(
                decoration: InputDecoration(
                  hintText: "Search items",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[300],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ITEMS LIST
              Expanded(
                child: ListView(
                  children: [
                    itemRow("Water Bottle", "12"),
                    itemRow("Gun", "12"),
                    itemRow("Uniform", "12"),
                    itemRow("Hat", "15"),
                    itemRow("Grenade", "15"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget batchTab(String title, bool active) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(title,
          style: TextStyle(color: active ? Colors.white : Colors.black)),
    );
  }

  Widget itemRow(String name, String qty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(qty),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
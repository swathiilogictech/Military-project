import 'package:flutter/material.dart';
import 'package:military_app/givescreen.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const DashboardPage(),   // index 0 → Home
    const GiveCollectPage(), // index 1 → Give/Collect
    const Placeholder(),
    const Placeholder(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: Colors.teal,       // 👈 active icon color
        unselectedItemColor: Colors.grey,     // 👈 inactive icon color

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz), // 👈 Give/Collect
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: "",
          ),
        ],
      ),
    );
  }
}
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [

              // TITLE
              const Text(
                "Package Tracking",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // SEARCH BAR
              TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[300],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // GRID CARDS
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [

                      // ROW 1
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          dashboardCard("Number of Cadets", "5", Colors.green),
                          dashboardCard("Given Items", "32", Colors.purple),
                          dashboardCard("Collected Items", "17", Colors.pink),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // ROW 2
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          dashboardCard("Batches", "5", Colors.blueGrey),
                          dashboardCard("Boxes", "25", Colors.red),
                          dashboardCard("Items", "90", Colors.brown),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // BUTTON
                      Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            "Recent Transfers",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // TABLE HEADER
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text("Profile"),
                            Text("Name/ID"),
                            Text("Taken"),
                            Text("Returned"),
                            Text("Time"),
                            Text("Edit"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // LIST ITEMS
                      transferRow("Daniel", "24023100", "7", "-", "05/04/2026\n1:10pm"),
                      transferRow("Subash", "24023167", "-", "5", "14/04/2026\n10:18pm"),
                      transferRow("Swathi", "24023141", "-", "5", "08/04/2026\n11:28pm"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

    );
  }

  // DASHBOARD CARD
  Widget dashboardCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(12),
        height: 110,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            Text(count,
                style: const TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // TRANSFER ROW
  Widget transferRow(String name, String id, String taken, String returned, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          const CircleAvatar(radius: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(id, style: const TextStyle(fontSize: 12)),
            ],
          ),

          Text(taken),
          Text(returned),
          Text(time, style: const TextStyle(fontSize: 10)),
          const Icon(Icons.edit),
        ],
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';

import 'db/database_helper.dart';
import 'screens/logo_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  unawaited(DatabaseHelper.instance.database);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'Ledger App',

      theme: ThemeData(

        useMaterial3: true,

        primarySwatch: Colors.green,

        scaffoldBackgroundColor:
            Colors.grey.shade100,
      ),

      home: const LogoScreen(nextScreen: HomeScreen(), duration: Duration(seconds: 3)),
    );
  }
}

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        elevation: 0,

        centerTitle: true,

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,

        title: const Text(
          "Ledger App",
        ),
      ),

      body: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            const SizedBox(height: 20),

            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(20),

                boxShadow: [

                  BoxShadow(

                    color: Colors.grey
                        .withOpacity(0.2),

                    blurRadius: 10,

                    offset: const Offset(0, 5),
                  ),
                ],
              ),

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  const Text(

                    "Welcome 👋",

                    style: TextStyle(

                      fontSize: 24,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(

                    "Your SQLite database is connected successfully.",

                    style: TextStyle(

                      fontSize: 16,

                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(

                    padding:
                        const EdgeInsets.symmetric(

                      horizontal: 14,
                      vertical: 10,
                    ),

                    decoration: BoxDecoration(

                      color: Colors.green
                          .withOpacity(0.1),

                      borderRadius:
                          BorderRadius.circular(12),
                    ),

                    child: const Row(

                      children: [

                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),

                        SizedBox(width: 10),

                        Expanded(

                          child: Text(

                            "Database Connected Successfully",

                            style: TextStyle(

                              fontWeight:
                                  FontWeight.w600,

                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(

              "Project Modules",

              style: TextStyle(

                fontSize: 20,

                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(

              child: GridView.count(

                crossAxisCount: 2,

                crossAxisSpacing: 15,

                mainAxisSpacing: 15,

                children: [

                  buildCard(
                    title: "Businesses",
                    icon: Icons.business,
                  ),

                  buildCard(
                    title: "Accounts",
                    icon: Icons.account_balance_wallet,
                  ),

                  buildCard(
                    title: "Transactions",
                    icon: Icons.receipt_long,
                  ),

                  buildCard(
                    title: "Balance Sheet",
                    icon: Icons.bar_chart,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCard({

    required String title,
    required IconData icon,

  }) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(

            color:
                Colors.grey.withOpacity(0.15),

            blurRadius: 8,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(

        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          Icon(

            icon,

            size: 45,

            color: Colors.green,
          ),

          const SizedBox(height: 15),

          Text(

            title,

            style: const TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
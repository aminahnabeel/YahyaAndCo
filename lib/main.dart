import 'package:flutter/material.dart';
import 'db/database_helper.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: Scaffold(

        appBar: AppBar(
          title: const Text("Ledger App"),
        ),

        body: const Center(
          child: Text(
            "SQLite Connected Successfully",
          ),
        ),
      ),
    );
  }
}
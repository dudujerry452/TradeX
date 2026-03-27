// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MainApp());
// }

// class MainApp extends StatelessWidget {
//   const MainApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       home: Scaffold(
//         body: Center(
//           child: Text('Hello World!'),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tradeX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 使用系统默认字体，避免字体加载延迟
        fontFamily: 'Roboto', // Android 系统默认字体
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
import 'package:flutter/material.dart';
// AccountStatusPage.dart 파일의 실제 경로로 수정해주세요.
// 예: import 'pages/account_status_page.dart';
import 'package:stock_rebalence/pages/stock_status_page.dart'; // 이전 단계에서 생성한 파일

// WODS-master 프로젝트의 main.dart 처럼 Provider 등의 상태관리 설정을 추가할 수 있습니다.
// 예시에서는 간단하게 MaterialApp만 사용합니다.

void main() async {
  // WODS-master/lib/main.dart 처럼 Firebase나 Hive 초기화가 필요하다면 여기에 추가합니다.
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  // await Hive.initFlutter();
  // await Hive.openBox('app_state');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // WODS-master/lib/main.dart 의 MaterialApp 설정을 참고하여 테마 등을 적용할 수 있습니다.
    return MaterialApp(
      title: '주식 계좌 앱',
      theme: ThemeData( // WODS-master 프로젝트의 라이트 테마 참고
        primarySwatch: Colors.blue, // 예시 기본 테마
        useMaterial3: true, // 최신 Material 디자인 사용 권장
        // WODS-master/lib/main.dart의 ThemeData 내용 참고하여 커스텀
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[50],
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            elevation: MaterialStateProperty.all<double>(0),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            backgroundColor: MaterialStateProperty.all<Color>(const Color.fromRGBO(240, 154, 105, 1)), // WODS-master의 주조색
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith( // WODS-master 프로젝트의 다크 테마 참고
        useMaterial3: true,
        // WODS-master/lib/main.dart의 ThemeData 내용 참고하여 커스텀
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            elevation: MaterialStateProperty.all<double>(0),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.black),
            backgroundColor: MaterialStateProperty.all<Color>(const Color.fromRGBO(240, 154, 105, 1)), // WODS-master의 주조색
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system, // 시스템 설정에 따라 테마 변경 (WODS-master 참고)
      home: const AccountStatusPage(), // 앱의 첫 화면으로 AccountStatusPage 설정
      debugShowCheckedModeBanner: false, // WODS-master 참고
      // 만약 WODS-master 처럼 여러 페이지를 사용한다면 RouteGenerator를 설정할 수 있습니다.
      // onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
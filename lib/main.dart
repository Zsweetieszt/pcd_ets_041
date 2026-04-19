import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:helpers/log_helper.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/logbook/models/log_model.dart';
import 'features/onboarding/onboarding_view.dart';

List<CameraDescription> cameras =
    []; // Variabel global untuk menyimpan daftar kamera

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // VERIFIKASI KETERSEDIAAN KAMERA
  try {
    cameras = await availableCameras();
    await LogHelper.writeLog(
      'Available cameras: ${cameras.length}',
      source: 'main.dart',
      level: 2,
    );
  } on CameraException catch (e) {
    await LogHelper.writeLog(
      'Camera Error: ${e.code}\nError Message: ${e.description}',
      source: 'main.dart',
      level: 1,
    );
  }

  // Inisialisasi locale Indonesia untuk format tanggal
  await initializeDateFormatting('id', null);
  await Hive.initFlutter();
  Hive.registerAdapter(LogModelAdapter());
  await Hive.openBox<LogModel>('logs_box');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true, // Menggunakan desain Material 3 yang modern
      ),
      debugShowCheckedModeBanner: false,
      home: const OnboardingView(),
    );
  }
}
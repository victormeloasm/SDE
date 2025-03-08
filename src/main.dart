import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

const String weatherApiKey = "03cf51765b5c40638f8120603250803";

// Fabric and color properties
const Map<String, double> fabricResistance = {
  "Cotton": 70,
  "Polyester": 40,
  "Wool": 100,
  "Silk": 50,
  "Denim": 80,
  "Linen": 60
};

const Map<String, double> colorAbsorption = {
  "White": 0.8,
  "Black": 1.2,
  "Blue": 1.0,
  "Red": 1.1,
  "Green": 0.9,
  "Yellow": 0.85
};

/// Uses a Penman-Monteith–based formula to compute an evaporation rate,
/// then inverts it to estimate drying time (in hours).
/// - Higher ET => Less drying time.
/// - Lower ET => More drying time.
double calculateDryingTime(
    double temp, double humidity, double wind, String fabric, String color) {
  // 1) Compute the evapotranspiration (ET) rate
  double delta = 4098 *
      (0.6108 * exp((17.27 * temp) / (temp + 237.3))) /
      pow((temp + 237.3), 2);
  double gamma = 0.665 * 0.001 * 101.3;
  double rn = 2.5 * (colorAbsorption[color] ?? 1.0); // Net radiation adjusted by color
  double g = 0.1;
  double cp = 1.013;
  double p = 101.3;
  double ra = (wind <= 0) ? 999999 : (208 / wind); // Avoid division by zero
  double rs = fabricResistance[fabric] ?? 70;      // Fabric resistance
  double es = 0.6108 * exp((17.27 * temp) / (temp + 237.3));
  double ea = (humidity / 100.0) * es;

  double evapotranspiration = (delta * (rn - g) + (p * cp * (es - ea) / ra)) /
      (delta + gamma * (1 + rs / ra));

  // 2) Convert the evaporation rate into an approximate drying time (in hours).
  const drynessFactor = 60.0; 
  if (evapotranspiration <= 0) {
    // If ET is non-positive, return a fallback
    return 48.0; 
  }
  return drynessFactor / evapotranspiration;
}

void main() {
  runApp(const ShirtDryingEstimatorApp());
}

class ShirtDryingEstimatorApp extends StatelessWidget {
  const ShirtDryingEstimatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Shirt Drying Estimator",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const DryingEstimatorScreen(),
    );
  }
}

class DryingEstimatorScreen extends StatefulWidget {
  const DryingEstimatorScreen({super.key});

  @override
  _DryingEstimatorScreenState createState() => _DryingEstimatorScreenState();
}

class _DryingEstimatorScreenState extends State<DryingEstimatorScreen> {
  final TextEditingController tempController = TextEditingController();
  final TextEditingController humidityController = TextEditingController();
  final TextEditingController windController = TextEditingController();
  String selectedFabric = 'Cotton';
  String selectedColor = 'White';
  String dryingTimeResult = "";
  String? cityName;
  bool isLoading = false;
  bool locationDenied = false;

  // Location and weather are fetched only when the user clicks the button.
  Future<void> _getLocationAndWeather() async {
    setState(() => isLoading = true);
    try {
      // Solicita permissão de localização, se necessário.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          dryingTimeResult =
              "Location permission denied. Please enter data manually.";
          locationDenied = true;
        });
        setState(() => isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await _fetchWeather(position.latitude, position.longitude);
      setState(() => locationDenied = false);
    } catch (e) {
      setState(() {
        dryingTimeResult = "Error fetching location/weather: $e";
        locationDenied = true;
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    final url =
        "https://api.weatherapi.com/v1/current.json?key=$weatherApiKey&q=$lat,$lon";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          tempController.text = data['current']['temp_c'].toString();
          humidityController.text = data['current']['humidity'].toString();
          windController.text = data['current']['wind_kph'].toString();
          cityName = data['location']['name'];
        });
      } else {
        setState(() => dryingTimeResult = "Failed to fetch weather data.");
      }
    } catch (e) {
      setState(() => dryingTimeResult = "Error fetching weather data: $e");
    }
  }

  void calculate() {
    if (tempController.text.isEmpty ||
        humidityController.text.isEmpty ||
        windController.text.isEmpty) {
      setState(() {
        dryingTimeResult =
            "Error: All fields must be filled before calculating.";
      });
      return;
    }

    double temp = double.tryParse(tempController.text) ?? 25.0;
    double humidity = double.tryParse(humidityController.text) ?? 50.0;
    double wind = double.tryParse(windController.text) ?? 5.0;
    double result =
        calculateDryingTime(temp, humidity, wind, selectedFabric, selectedColor);
    setState(() {
      dryingTimeResult = "Estimated Drying Time: ${result.toStringAsFixed(2)} hours";
    });
  }

  Future<void> _showAboutDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "About",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30), // Espaço para o botão de fechar
                      const Text(
                        "About",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Developer: Víctor Duarte Melo\nYear: 2025\n\nThis app uses the Penman-Monteith equation for drying time estimation.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shirt Drying Estimator"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "About",
            onPressed: _showAboutDialog,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (cityName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            "City: $cityName",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Dropdown para selecionar o tecido
                      DropdownButton<String>(
                        value: selectedFabric,
                        onChanged: (String? newValue) {
                          setState(() => selectedFabric = newValue!);
                        },
                        items: fabricResistance.keys
                            .map((String fabric) => DropdownMenuItem(
                                value: fabric, child: Text(fabric)))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      // Dropdown para selecionar a cor
                      DropdownButton<String>(
                        value: selectedColor,
                        onChanged: (String? newValue) {
                          setState(() => selectedColor = newValue!);
                        },
                        items: colorAbsorption.keys
                            .map((String color) => DropdownMenuItem(
                                value: color, child: Text(color)))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      // TextFields para dados do clima
                      TextField(
                        controller: tempController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: "Temperature (°C)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: humidityController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: "Humidity (%)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: windController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: "Wind (km/h)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Botões para calcular e atualizar o clima
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: calculate,
                            child: const Text("Calculate Drying Time"),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: _getLocationAndWeather,
                            child: const Text("Update Weather"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        dryingTimeResult,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String weatherApiKey = "YOUR_API_KEY";

defaultFabricValues(String fabric) {
  switch (fabric) {
    case 'Cotton':
      return 1.5;
    case 'Polyester':
      return 1.0;
    case 'Wool':
      return 2.0;
    default:
      return 1.5;
  }
}

double calculateDryingTime(double temp, double humidity, double wind, String fabric) {
  double fabricFactor = defaultFabricValues(fabric);
  return (100 - temp) * (humidity / 100) * fabricFactor / (wind + 1);
}

void main() {
  runApp(ShirtDryingEstimatorApp());
}

class ShirtDryingEstimatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DryingEstimatorScreen(),
    );
  }
}

class DryingEstimatorScreen extends StatefulWidget {
  @override
  _DryingEstimatorScreenState createState() => _DryingEstimatorScreenState();
}

class _DryingEstimatorScreenState extends State<DryingEstimatorScreen> {
  final TextEditingController tempController = TextEditingController();
  final TextEditingController humidityController = TextEditingController();
  final TextEditingController windController = TextEditingController();
  String selectedFabric = 'Cotton';
  String dryingTimeResult = "";

  Future<void> _getLocationAndWeather() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        dryingTimeResult = "Location services are disabled";
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          dryingTimeResult = "Location permissions are denied";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        dryingTimeResult = "Location permissions are permanently denied";
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _fetchWeather(position.latitude, position.longitude);
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    final url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        tempController.text = data['main']['temp'].toString();
        humidityController.text = data['main']['humidity'].toString();
        windController.text = data['wind']['speed'].toString();
      });
    } else {
      setState(() {
        dryingTimeResult = "Failed to fetch weather data";
      });
    }
  }

  void calculate() {
    double temp = double.tryParse(tempController.text) ?? 25.0;
    double humidity = double.tryParse(humidityController.text) ?? 50.0;
    double wind = double.tryParse(windController.text) ?? 5.0;

    double result = calculateDryingTime(temp, humidity, wind, selectedFabric);
    setState(() {
      dryingTimeResult = "Estimated Drying Time: ${result.toStringAsFixed(2)} hours";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Shirt Drying Estimator")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _getLocationAndWeather,
              child: Text("Get Weather Data"),
            ),
            TextField(
              controller: tempController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Temperature (°C)"),
            ),
            TextField(
              controller: humidityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Humidity (%)"),
            ),
            TextField(
              controller: windController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Wind Speed (km/h)"),
            ),
            DropdownButton<String>(
              value: selectedFabric,
              onChanged: (String? newValue) {
                setState(() {
                  selectedFabric = newValue!;
                });
              },
              items: ["Cotton", "Polyester", "Wool"].map((String fabric) {
                return DropdownMenuItem(
                  value: fabric,
                  child: Text(fabric),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: calculate,
              child: Text("Calculate Drying Time"),
            ),
            SizedBox(height: 20),
            Text(dryingTimeResult, style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
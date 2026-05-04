import 'package:flutter/material.dart';

class WeatherData {
  final String city;
  final double temperature;
  final String condition;
  final IconData icon;
  final int humidity;
  final double windSpeed;
  final bool travelWarning;
  final String warningMessage;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    this.travelWarning = false,
    this.warningMessage = '',
  });
}

// Dummy Weather Data for Pakistan Cities
class PakistanWeatherData {
  static List<String> getCities() {
    return [
      'Karachi',
      'Lahore',
      'Islamabad',
      'Rawalpindi',
      'Faisalabad',
      'Multan',
      'Peshawar',
      'Quetta',
      'Sialkot',
      'Gujranwala',
      'Bahawalpur',
      'Hyderabad',
      'Sukkur',
      'Larkana',
      'Gwadar',
      'Murree',
      'Nathiagali',
      'Abbottabad',
      'Swat',
      'Gilgit',
      'Skardu',
      'Hunza',
      'Naran',
      'Chitral',
      'Muzaffarabad',
      'Ziarat',
    ];
  }

  static WeatherData getWeatherForCity(String city) {
    // Dummy weather data - in real app, this would come from API
    switch (city) {
      case 'Karachi':
        return WeatherData(
          city: city,
          temperature: 32.0,
          condition: 'Partly Cloudy',
          icon: Icons.wb_cloudy,
          humidity: 65,
          windSpeed: 15.5,
          travelWarning: false,
          warningMessage: '',
        );
      case 'Lahore':
        return WeatherData(
          city: city,
          temperature: 28.0,
          condition: 'Sunny',
          icon: Icons.wb_sunny,
          humidity: 45,
          windSpeed: 8.2,
          travelWarning: false,
          warningMessage: '',
        );
      case 'Islamabad':
        return WeatherData(
          city: city,
          temperature: 25.0,
          condition: 'Clear',
          icon: Icons.wb_sunny,
          humidity: 50,
          windSpeed: 10.0,
          travelWarning: false,
          warningMessage: '',
        );
      case 'Murree':
        return WeatherData(
          city: city,
          temperature: 12.0,
          condition: 'Rainy',
          icon: Icons.water_drop,
          humidity: 85,
          windSpeed: 20.0,
          travelWarning: true,
          warningMessage:
              'Heavy rain expected. Roads may be slippery. Travel with caution.',
        );
      case 'Quetta':
        return WeatherData(
          city: city,
          temperature: 18.0,
          condition: 'Windy',
          icon: Icons.air,
          humidity: 30,
          windSpeed: 25.0,
          travelWarning: true,
          warningMessage:
              'Strong winds forecasted. Outdoor activities not recommended.',
        );
      case 'Peshawar':
        return WeatherData(
          city: city,
          temperature: 30.0,
          condition: 'Hot',
          icon: Icons.local_fire_department,
          humidity: 40,
          windSpeed: 7.5,
          travelWarning: false,
          warningMessage: '',
        );
      case 'Multan':
        return WeatherData(
          city: city,
          temperature: 35.0,
          condition: 'Very Hot',
          icon: Icons.local_fire_department,
          humidity: 35,
          windSpeed: 12.0,
          travelWarning: true,
          warningMessage:
              'Extreme heat warning. Stay hydrated and avoid outdoor travel during peak hours.',
        );
      case 'Faisalabad':
        return WeatherData(
          city: city,
          temperature: 29.0,
          condition: 'Cloudy',
          icon: Icons.cloud,
          humidity: 55,
          windSpeed: 9.0,
          travelWarning: false,
          warningMessage: '',
        );
      case 'Gilgit':
        return WeatherData(
          city: city,
          temperature: 15.0,
          condition: 'Cool',
          icon: Icons.landscape,
          humidity: 60,
          windSpeed: 11.0,
          travelWarning: false,
          warningMessage: '',
        );
      case 'Skardu':
        return WeatherData(
          city: city,
          temperature: 10.0,
          condition: 'Cold',
          icon: Icons.ac_unit,
          humidity: 70,
          windSpeed: 14.0,
          travelWarning: true,
          warningMessage:
              'Cold weather alert. Carry warm clothing for mountain travel.',
        );
      default:
        return WeatherData(
          city: city,
          temperature: 27.0,
          condition: 'Pleasant',
          icon: Icons.wb_sunny,
          humidity: 50,
          windSpeed: 10.0,
          travelWarning: false,
          warningMessage: '',
        );
    }
  }

  static List<WeatherData> getAllCitiesWeather() {
    return getCities().map((city) => getWeatherForCity(city)).toList();
  }

  static List<WeatherData> getCitiesWithWarnings() {
    return getAllCitiesWeather()
        .where((weather) => weather.travelWarning)
        .toList();
  }
}

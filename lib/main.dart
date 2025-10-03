import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride Fare Estimator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentLatLng;
  Marker? _pickupMarker;
  Marker? _dropMarker;
  Set<Polyline> _polylines = {};
  double _fare = 0.0;
  String _pickupAddress = '';
  String _dropAddress = '';

  final String _googleApiKey = "add your api key"; // Replace with your API key

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
      _pickupMarker = Marker(
        markerId: const MarkerId('pickup'),
        position: _currentLatLng!,
        infoWindow: const InfoWindow(title: "Pickup"),
      );
    });

    _pickupAddress = await _getAddressFromLatLng(_currentLatLng!);

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng!, 14));
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks =
      await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return "${place.street}, ${place.locality}";
      }
    } catch (_) {}
    return "Unknown location";
  }

  void _onMapTapped(LatLng tappedPoint) async {
    setState(() {
      _dropMarker = Marker(
        markerId: const MarkerId('drop'),
        position: tappedPoint,
        infoWindow: const InfoWindow(title: "Drop-off"),
      );
    });

    _dropAddress = await _getAddressFromLatLng(tappedPoint);

    if (_pickupMarker != null && _dropMarker != null) {
      await _drawRouteWithDirectionsApi(
          _pickupMarker!.position, _dropMarker!.position);
    }
  }

  Future<void> _drawRouteWithDirectionsApi(
      LatLng origin, LatLng destination) async {
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&alternatives=true"
        "&key=$_googleApiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if ((data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final polyline = route['overview_polyline']['points'];
        final distanceMeters =
        route['legs'][0]['distance']['value']; // in meters
        final distanceKm = distanceMeters / 1000.0;

        setState(() {
          _fare = distanceKm * 1.0; // €1 per km
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            width: 5,
            color: Colors.blue,
            points: _decodePolyline(polyline),
          ));
        });
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
            CameraPosition(target: _currentLatLng!, zoom: 14),
            myLocationEnabled: true,
            onMapCreated: (c) => _controller.complete(c),
            markers: {
              if (_pickupMarker != null) _pickupMarker!,
              if (_dropMarker != null) _dropMarker!,
            },
            polylines: _polylines,
            onTap: _onMapTapped,
          ),
          if (_pickupMarker != null && _dropMarker != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: DraggableScrollableSheet(
                initialChildSize: 0.2,
                minChildSize: 0.2,
                maxChildSize: 0.4,
                builder: (context, scrollController) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Text("Pickup: $_pickupAddress"),
                        const SizedBox(height: 8),
                        Text("Drop-off: $_dropAddress"),
                        const SizedBox(height: 8),
                        Text(
                          "Estimated Fare: €${_fare.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}

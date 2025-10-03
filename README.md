# test_f
Note: the code in this repository is for test purposes only. It does not follow best practices or be optimized for production use.

This project is for test purposes. 
It does the following tasks:
1. Show the user’s current location on the map (with proper permission handling).
2. Place a marker at the current location.
3. Allow the user to tap anywhere on the map to place another marker (simulating “pickup” or “drop-off” points).
4. Draw a polyline (route) between the two markers.
5. Show an estimated fare based on distance ( €1 per km).
6. Add a bottom sheet UI showing pickup/drop-off addresses.


Also the project is configured only for android platform. And it contains the following dependencies:
- google_maps_flutter: ^2.5.0
- geolocator: ^11.0.0
- geocoding: ^2.1.0
- http: ^1.5.0

flutter sdk version used in this project is 3.35.5

if you want to run this project, please make sure to add your google map api key in android manifest file, also in the main.dart file.
And don't forget to enable the required APIs in your Google Cloud Console (Maps SDK for Android, Directions API).


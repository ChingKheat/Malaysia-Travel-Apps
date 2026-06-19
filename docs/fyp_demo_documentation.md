# Smart Travel Planning Mobile Application for Malaysia

## 1. Simple System Architecture

This demo uses a frontend-only architecture:

Flutter App -> OpenTripMap API -> OpenRouteService API -> UI

The Flutter application calls OpenTripMap to retrieve tourist attractions around Kuala Lumpur. The selected attraction coordinates are then sent to OpenRouteService to calculate route distance, travel time and route geometry. OpenStreetMap tiles are displayed through `flutter_map`, and the result is shown as markers, attraction cards and a route polyline.

There is no database, Firebase or backend server in this demo.

## 2. Demo Folder Structure

```text
lib/
  app/
  core/
  models/
    attraction.dart
    route_info.dart
  services/
    opentripmap_service.dart
    openroute_service.dart
    itinerary_service.dart
  screens/
    api_demo_page.dart
    attraction_list_screen.dart
    map_screen.dart
    attraction_detail_page.dart
  widgets/
```

## 3. API Workflow

1. The Flutter app loads the demo page.
2. The app calls the OpenTripMap radius API for attractions around Kuala Lumpur.
3. JSON data is parsed into `Attraction` model objects.
4. Attractions are shown in a list and as markers on the OpenStreetMap map.
5. A rule-based itinerary selects nearby attractions within a simple time limit.
6. The selected attractions are sent to OpenRouteService.
7. The route response is parsed into `RouteInfo`.
8. The app displays route polyline, distance and travel time.

## 4. Simple Itinerary Algorithm

The demo does not use machine learning or backend AI. The itinerary logic is rule-based:

1. Sort attractions by distance from Kuala Lumpur city center.
2. Add the nearest attraction to the itinerary.
3. Estimate travel time using simple distance-based speed.
4. Add a fixed visit duration of 45 minutes per stop.
5. Stop when the itinerary reaches 6 hours or 5 attractions.

## 5. Introduction

Tourists visiting Malaysia often need to compare attraction information, map locations and travel routes manually. This project proposes a Smart Travel Planning Mobile Application that helps tourists discover attractions, view them on a map and generate a simple travel itinerary.

## 6. Problem Statement

Manual travel planning can be time-consuming because tourists must search for places, check locations, compare travel distance and organize a realistic route. This can cause inefficient routes and poor time management, especially for independent tourists unfamiliar with Malaysia.

## 7. Objectives

- To fetch real tourist attraction data using OpenTripMap.
- To display attractions on an interactive OpenStreetMap map.
- To show attraction details in a mobile-friendly interface.
- To calculate route distance and travel time using OpenRouteService.
- To generate a simple rule-based itinerary for demo purposes.

## 8. Scope

This project is a Final Year Project demo prototype only.

Included:
- Flutter frontend.
- OpenTripMap API integration.
- OpenRouteService API integration.
- OpenStreetMap display using `flutter_map`.
- Attraction list, map markers, route polyline and detail page.
- Simple rule-based itinerary generation.

Excluded:
- Database.
- Firebase.
- Backend server.
- User authentication.
- Payment or booking system.
- Production AI or machine learning model.

## 9. System Overview

The user opens the mobile app and views attractions around Kuala Lumpur. The user can select two to five attractions for route planning. The app sends selected coordinates to OpenRouteService and displays the route on the map. The itinerary generator uses basic rules to recommend a small number of nearby places within a time limit.

## 10. Expected Output

The expected output is a runnable Flutter demo that can show Malaysia tourist attractions, display them on a map, calculate route distance and time, draw route lines and present a simple smart itinerary.

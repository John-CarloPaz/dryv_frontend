# Crucial Facilities Pills Feature

## Overview
This feature implements Google Maps-style horizontal pills for quick facility search using Mapbox Search Box API. The pills are placed under the search bar on the map screen.

## Files Created/Modified

### New Files:
1. **`lib/Models/facility_category.dart`**
   - Defines the `FacilityCategory` model
   - Contains predefined facility categories (Hospitals, Evacuation Centers, etc.)
   - Scalable design - easy to add more categories

2. **`lib/Services/mapbox_search_service.dart`**
   - Handles Mapbox Search Box API integration
   - Two search methods:
     - `searchNearbyFacilities()` - Category-based search
     - `searchWithForwardGeocoding()` - Fallback text-based search
   - Returns `FacilityResult` objects with location data

3. **`lib/Widgets/crucial_facilities.dart`**
   - Horizontal scrollable pills widget
   - Individual pill components with selection state
   - Animated selection with category colors

### Modified Files:
1. **`lib/Screens/Map/map_display.dart`**
   - Added facility pills below search bar
   - Integrated facility search functionality
   - Added facility annotation management
   - Loading state during search

## Features

### 1. **Facility Categories**
   - Hospitals (Red)
   - Evacuation Centers (Orange)
   - Charging Stations (Green)
   - Comfort Rooms (Blue)
   - Parking Lots (Purple)

### 2. **Search Behavior**
   - Uses current map center for proximity search
   - 10km radius search area
   - Returns up to 15 results
   - Fallback to text search if category search fails

### 3. **Visual Feedback**
   - Selected pill highlighted with category color
   - Loading indicator during search
   - Snackbar notifications for results/errors
   - Red pin markers for found facilities

### 4. **Toggle Functionality**
   - Click pill to search and show markers
   - Click again to clear markers
   - Only one category active at a time

## How to Add More Categories

In `lib/Models/facility_category.dart`, add to the `categories` list:

```dart
FacilityCategory(
  id: 'unique_id',
  label: 'Display Name',
  icon: Icons.icon_name,
  mapboxCategory: 'mapbox_poi_category',
  color: Colors.colorName,
),
```

## Mapbox API Integration

The implementation uses:
- **Mapbox Search Box API v1**
- Category endpoint: `/search/searchbox/v1/category/{category}`
- Forward geocoding: `/search/searchbox/v1/forward`
- Requires `MAPBOX_ACCESS_TOKEN` in `.env` file

## Scalability Features

1. **Modular Architecture**
   - Separate model, service, and widget layers
   - Easy to extend or modify

2. **Configurable Search Parameters**
   - Adjustable search radius
   - Customizable result limits
   - Multiple search strategies

3. **Annotation Management**
   - Efficient marker creation/deletion
   - Reuses existing annotation manager
   - No memory leaks

4. **Error Handling**
   - Graceful fallbacks
   - User-friendly error messages
   - Debug logging for troubleshooting

## Usage

The pills automatically appear on the map screen. Simply tap a pill to search for nearby facilities of that type. Tap again to clear the results.

## Notes

- GPS location is not required; uses visible map area center
- Search updates based on current map position
- Works with existing pin assets (`lib/assets/images/pin.png`)
- Compatible with existing map layers and annotations

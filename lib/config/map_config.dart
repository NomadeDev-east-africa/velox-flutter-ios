// Configuration OpenStreetMap pour Nomade 253
// ✅ PAS BESOIN DE CLÉ API !

class MapConfig {
  // Position initiale (Djibouti-Ville)
  static const double defaultLatitude = 11.5721;
  static const double defaultLongitude = 43.1456;
  static const double defaultZoom = 13.0;
  
  // Zoom min/max
  static const double minZoom = 5.0;
  static const double maxZoom = 18.0;
  
  // URL des tuiles OpenStreetMap (style clair/light)
  // Option 1 : Style classique (recommandé)
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  
  // Option 2 : Style CartoDB Light (encore plus clair)
  // static const String tileUrl = 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png';
  
  // Option 3 : Style HOT (Humanitarian OpenStreetMap)
  // static const String tileUrl = 'https://tile-a.openstreetmap.fr/hot/{z}/{x}/{y}.png';
  
  // Attribution (obligatoire pour OpenStreetMap)
  static const String attribution = '© OpenStreetMap contributors';
}

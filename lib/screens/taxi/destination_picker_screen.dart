import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomade_client/constants.dart';
import 'package:nomade_client/models/place.dart';
import '../../providers/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../services/location_service.dart';


class DestinationPickerScreen extends ConsumerStatefulWidget {
  final Place currentLocation;

  const DestinationPickerScreen({
    super.key,
    required this.currentLocation,
  });

  @override
  ConsumerState<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends ConsumerState<DestinationPickerScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // ✅ SUPPRIMÉ toutes les variables GPS :
  // LatLng? _destinationPosition;
  // String? _destinationAddress;
  // bool _isLoadingAddress = false;
  // Timer? _mapMoveDebounceTimer;

  // ✅ AJOUTÉ : Variable pour tracker la position custom
  LatLng? _customDestinationPosition;

  // Adresse de destination gérée localement (ne passe PAS par locationNotifierProvider
  // car ce provider n'écrit state.address que si position == state.position GPS)
  String? _destinationAddress;
  bool    _isResolvingAddress = false;

  // ✅ GARDÉ : Variables pour la recherche de lieux
  bool _showSearchResults = false;
  List<PlaceResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;       // Pour le debouncing des recherches
  Timer? _mapMoveDebounceTimer; // Pour le debouncing du geocoding sur déplacement carte

  bool _isDarkMap = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 DestinationPickerScreen - initState()');

    // Initialiser la position du pin sur le centre de la carte
    // Ne pas appeler getAddressForPosition ici : ça résoudrait l'adresse du pickup,
    // ce qui ferait confirmer la destination = pickup si l'utilisateur ne bouge pas la carte
    _customDestinationPosition = widget.currentLocation.location;
  }

  @override
  void dispose() {
    debugPrint('🛑 DestinationPickerScreen - dispose()');
    _searchController.dispose();
    _debounceTimer?.cancel();
    _mapMoveDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveDestinationAddress(LatLng position) async {
    if (!mounted) return;
    setState(() => _isResolvingAddress = true);
    try {
      final addr = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (mounted) setState(() { _destinationAddress = addr; _isResolvingAddress = false; });
    } catch (_) {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  // ✅ GARDÉ : Recherche de lieux (c'est différent du GPS)
  void _searchPlaces(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    _debounceTimer = Timer(Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      debugPrint('🔍 Recherche en cours: "$query"');

      try {
        final results = await _locationService.searchPlaces(query);
        debugPrint('📦 ${results.length} résultats trouvés');

        if (mounted) {
          setState(() {
            _searchResults = results;
            _showSearchResults = true;
            _isSearching = false;
          });
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Erreur recherche: $e');
        debugPrint('📝 Stack trace: $stackTrace');

        if (mounted) {
          setState(() {
            _isSearching = false;
            _showSearchResults = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recherche limitée - Vérifiez votre connexion'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  void _selectSearchResult(PlaceResult place) {
    debugPrint('✅ Sélection résultat: ${place.name}');

    final position = LatLng(place.latitude, place.longitude);
    setState(() {
      _customDestinationPosition = position;
      _destinationAddress        = place.name;
      _showSearchResults          = false;
      _searchController.text      = place.name;
    });

    _mapController.move(position, 16.0);
    FocusScope.of(context).unfocus();
  }

  // ✅ SUPPRIMÉ : void _onMapPositionChanged(LatLng newPosition) { ... }

  void _confirmDestination() {
    debugPrint('🎯 _confirmDestination - Début');

    final destinationPosition = _customDestinationPosition;
    final destinationAddress  = _destinationAddress;

    debugPrint('🎯 destinationPosition: $destinationPosition');
    debugPrint('🎯 destinationAddress: "$destinationAddress"');

    if (destinationPosition == null || destinationAddress == null || destinationAddress.isEmpty) {
      debugPrint('❌ Destination non valide');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez une destination valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final destination = Place(
      id: 'dest_${DateTime.now().millisecondsSinceEpoch}',
      name: destinationAddress,
      location: destinationPosition,
      address: destinationAddress,
      type: PlaceType.search,
    );

    debugPrint('✅ Retour TaxiHomeScreen avec destination sélectionnée');
    // ✅ On retourne la destination au TaxiHomeScreen via pop
    // TaxiHomeScreen récupère ce Place et affiche la carte de route + prix
    Navigator.pop(context, destination);
  }

  String get _mapTileUrl => _isDarkMap
      ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
      : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  Widget _buildAddressLoadingIndicator(AppColors c) {
    return Column(
      children: [
        Container(
          height: 20,
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              backgroundColor: c.surfaceHigh,
              color: c.error.withValues(alpha: 0.5),
              minHeight: 20,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Chargement de l\'adresse...',
          style: TextStyle(
            fontSize: 12,
            color: c.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeNotifierProvider).isDarkMode;
    final c = isDark ? AppColors.dark : AppColors.light;
    final destinationPosition = _customDestinationPosition
        ?? widget.currentLocation.location;
    final destinationAddress  = _destinationAddress;
    final isLoadingAddress    = _isResolvingAddress;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Map avec debouncing automatique via LocationProvider
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destinationPosition,
              initialZoom: 16.0,
              maxZoom: 18,
              minZoom: 10,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  final center = position.center;
                  setState(() => _customDestinationPosition = center);

                  _mapMoveDebounceTimer?.cancel();
                  _mapMoveDebounceTimer = Timer(
                    const Duration(milliseconds: 600),
                    () => _resolveDestinationAddress(center),
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _mapTileUrl,
                userAgentPackageName: 'com.nomade253.app',
              ),
              // Pin destination
              MarkerLayer(
                markers: [
                  Marker(
                    point: destinationPosition,
                    width: 50,
                    height: 70,
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 50,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Toggle thème map
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceLow,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: IconButton(
                iconSize: 24,
                icon: Icon(
                  _isDarkMap ? Icons.light_mode : Icons.dark_mode,
                  color: c.onSurface,
                ),
                onPressed: () {
                  debugPrint('🎨 Changement thème: $_isDarkMap → ${!_isDarkMap}');
                  setState(() => _isDarkMap = !_isDarkMap);
                },
              ),
            ),
          ),

          // Barre de recherche avec debouncing
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 72,
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceLow,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchPlaces,
                style: TextStyle(fontSize: 17, color: c.onSurface),
                decoration: InputDecoration(
                  hintText: 'Où allez-vous ?',
                  hintStyle: TextStyle(color: c.onSurfaceVariant, fontSize: 17),
                  prefixIcon: const Icon(Icons.search, color: secondaryColor, size: 26),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: c.onSurfaceVariant),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _showSearchResults = false;
                        _searchResults = [];
                      });
                      FocusScope.of(context).unfocus();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
          ),

          // Résultats de recherche
          if (_showSearchResults)
            Positioned(
              top: MediaQuery.of(context).padding.top + 90,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 200,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceLow,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Résultats',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_searchResults.length} trouvé(s)',
                            style: TextStyle(
                              fontSize: 14,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 0, color: c.outlineVariant),
                    Expanded(
                      child: _isSearching
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: secondaryColor),
                            const SizedBox(height: 16),
                            Text(
                              'Recherche en cours...',
                              style: TextStyle(color: c.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                          : _searchResults.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 60,
                              color: c.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun résultat trouvé',
                              style: TextStyle(
                                fontSize: 16,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Essayez avec d\'autres termes',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                          : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => Divider(height: 16, color: c.outlineVariant),
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: secondaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: secondaryColor,
                                size: 26,
                              ),
                            ),
                            title: Text(
                              place.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                            onTap: () => _selectSearchResult(place),
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Panneau bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              decoration: BoxDecoration(
                color: c.surfaceLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Départ
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: primaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Départ',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.currentLocation.address ?? 'Position actuelle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Destination
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Destination',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            isLoadingAddress
                                ? _buildAddressLoadingIndicator(c)
                                : Text(
                              destinationAddress ?? 'Déplacez le pin sur la carte',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Instructions
                  if (!isLoadingAddress && destinationAddress != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: c.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Déplacez la carte pour ajuster la destination',
                              style: TextStyle(
                                fontSize: 13,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Bouton confirmer
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: !isLoadingAddress ? _confirmDestination : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Ink(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [secondaryColor, primaryColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: secondaryColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Center(
                            child: isLoadingAddress
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Chargement...',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                                : const Text(
                              'Confirmer la destination',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/services/location_service.dart';
import 'package:nomade_client/theme/app_colors.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingAddress;

  const AddAddressScreen({super.key, this.existingAddress});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailsController = TextEditingController();
  final _searchController = TextEditingController();

  final MapController _mapController = MapController();
  Timer? _mapMoveTimer;
  Timer? _debounceTimer;

  LatLng? _selectedLocation;
  bool _isDarkMap = false;
  bool _isInitialized = false;
  bool _showSearchResults = false;
  bool _isSearching = false;
  bool _isLoadingAddress = false;
  bool _isLoadingInitialLocation = false;

  List<PlaceResult> _searchResults = [];
  String _selectedType = 'home';
  final ScrollController _scrollController = ScrollController();

  late AppColors _c;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 AddAddressScreen - initState()');

    if (widget.existingAddress != null) {
      _initializeWithExistingLocation();
    } else {
      _initializePosition();
    }
  }

  void _initializeWithExistingLocation() {
    if (widget.existingAddress != null) {
      _nameController.text = widget.existingAddress!['name'];
      _addressController.text = widget.existingAddress!['address'];
      _detailsController.text = widget.existingAddress!['details'] ?? '';
      _selectedType = widget.existingAddress!['type'];
      _selectedLocation = LatLng(
        widget.existingAddress!['latitude'],
        widget.existingAddress!['longitude'],
      );

      setState(() {
        _isInitialized = true;
      });

      _moveMapToLocation(_selectedLocation!, 16.0);
    }
  }

  Future<void> _initializePosition() async {
    setState(() {
      _isLoadingInitialLocation = true;
    });

    try {
      final locNotifier = ref.read(locationNotifierProvider.notifier);

      if (!ref.read(locationNotifierProvider).hasPosition) {
        debugPrint('📍 Aucune position disponible - Obtention de la position...');
        await locNotifier.getCurrentLocation();
      }

      final position = ref.read(locationNotifierProvider).position ??
          const LatLng(11.5880, 43.1450);

      setState(() {
        _selectedLocation = position;
        _isInitialized = true;
        _isLoadingInitialLocation = false;
      });

      _moveMapToLocation(position, 16.0);

      debugPrint('✅ Position initialisée: $position');

      _loadAddressForPosition(position);

    } catch (e) {
      debugPrint('❌ Erreur initialisation position: $e');

      const defaultPosition = LatLng(11.5880, 43.1450);
      setState(() {
        _selectedLocation = defaultPosition;
        _isInitialized = true;
        _isLoadingInitialLocation = false;
      });

      _moveMapToLocation(defaultPosition, 12.0);
    }
  }

  void _moveMapToLocation(LatLng position, double zoom) {
    _mapMoveTimer?.cancel();
    _mapMoveTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        try {
          _mapController.move(position, zoom);
          debugPrint('✅ Carte déplacée à: $position');
        } catch (e) {
          debugPrint('⚠️ Erreur déplacement carte: $e');
        }
      }
    });
  }

  Future<void> _loadAddressForPosition(LatLng position) async {
    if (_isLoadingAddress) return;

    setState(() => _isLoadingAddress = true);

    try {
      final addr = await ref.read(locationNotifierProvider.notifier).getAddressForPosition(position);

      if (mounted && addr != null && _addressController.text.isEmpty) {
        _addressController.text = addr;
      }

      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement adresse: $e');
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _searchPlaces(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      debugPrint('🔍 Recherche adresse: "$query"');

      try {
        final locationService = LocationService();
        final results = await locationService.searchPlaces(query);
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
    debugPrint('✅ Sélection adresse: ${place.name}');

    final position = LatLng(place.latitude, place.longitude);
    setState(() {
      _selectedLocation = position;
      _showSearchResults = false;
      _searchController.text = place.name;
    });

    _addressController.text = place.name;

    _moveMapToLocation(position, 16.0);

    _loadAddressForPosition(position);

    FocusScope.of(context).unfocus();
  }

  Widget _buildTypeSelector() {
    final types = [
      {'value': 'home', 'label': 'Maison', 'icon': Icons.home},
      {'value': 'work', 'label': 'Bureau', 'icon': Icons.work},
      {'value': 'other', 'label': 'Autre', 'icon': Icons.location_on},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedType == type['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedType = type['value'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _c.primary.withValues(alpha: 0.12)
                      : _c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _c.primary : _c.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: isSelected ? _c.primary : _c.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _c.primary : _c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _saveAddress() {
    debugPrint('💾 Sauvegarder l\'adresse');

    if (_formKey.currentState!.validate()) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une position sur la carte'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final address = {
        'name': _nameController.text,
        'address': _addressController.text,
        'details': _detailsController.text,
        'type': _selectedType,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'isDefault': false,
      };

      debugPrint('✅ Adresse à sauvegarder: $address');
      Navigator.pop(context, address);
    }
  }

  @override
  void dispose() {
    debugPrint('🛑 AddAddressScreen - dispose()');
    _mapMoveTimer?.cancel();
    _debounceTimer?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _detailsController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _mapTileUrl => _isDarkMap
      ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
      : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

  @override
  Widget build(BuildContext context) {
    _isDark = ref.watch(themeNotifierProvider).isDarkMode;
    _c = _isDark ? AppColors.dark : AppColors.light;

    final locationState    = ref.watch(locationNotifierProvider);
    final isLoadingAddress = locationState.isLoading;

    final displayPosition = _selectedLocation ??
        locationState.position ??
        const LatLng(11.5880, 43.1450);
    final displayAddress = _addressController.text.isNotEmpty
        ? _addressController.text
        : locationState.address;

    if (_isLoadingInitialLocation) {
      return Scaffold(
        backgroundColor: _c.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _c.primary),
              const SizedBox(height: 16),
              Text(
                widget.existingAddress != null
                    ? 'Chargement de l\'adresse existante...'
                    : 'Obtention de votre position...',
                style: TextStyle(
                  fontSize: 16,
                  color: _c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _c.bg,
      appBar: AppBar(
        title: Text(
          widget.existingAddress != null ? 'Modifier l\'adresse' : 'Ajouter une adresse',
          style: TextStyle(color: _c.onSurface, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _c.bg,
        foregroundColor: _c.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMap ? Icons.light_mode : Icons.dark_mode,
              color: _c.primary,
            ),
            onPressed: () {
              setState(() => _isDarkMap = !_isDarkMap);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: displayPosition,
                    initialZoom: _isInitialized ? 16.0 : 12.0,
                    maxZoom: 18,
                    minZoom: 10,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        final center = position.center;
                        debugPrint('🗺️ Carte déplacée: ${center.latitude}, ${center.longitude}');

                        setState(() {
                          _selectedLocation = center;
                        });

                        ref.read(locationNotifierProvider.notifier).getAddressForPosition(center);

                        _loadAddressForPosition(center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _mapTileUrl,
                      userAgentPackageName: 'com.nomade253.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: displayPosition,
                          width: 50,
                          height: 70,
                          child: Icon(
                            Icons.location_pin,
                            color: _c.primary,
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

                // Barre de recherche
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _c.surfaceLow,
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
                      style: TextStyle(fontSize: 17, color: _c.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une adresse...',
                        hintStyle: TextStyle(color: _c.onSurfaceVariant, fontSize: 17),
                        prefixIcon: Icon(Icons.search, color: _c.primary, size: 26),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, size: 20, color: _c.onSurfaceVariant),
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
                    top: 90,
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _c.surfaceLow,
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
                                    color: _c.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_searchResults.length} trouvé(s)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 0),
                          Expanded(
                            child: _isSearching
                                ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: _c.primary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Recherche en cours...',
                                    style: TextStyle(color: _c.onSurfaceVariant),
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
                                    color: _c.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun résultat trouvé',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _c.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Essayez avec d\'autres termes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _c.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _searchResults.length,
                              separatorBuilder: (context, index) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final place = _searchResults[index];
                                return ListTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _c.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: _c.primary,
                                      size: 26,
                                    ),
                                  ),
                                  title: Text(
                                    place.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _c.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _c.onSurfaceVariant,
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

                // Bouton localisation actuelle
                Positioned(
                  top: 90,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: _initializePosition,
                    backgroundColor: _c.surfaceLow,
                    child: Icon(Icons.my_location, color: _c.primary),
                  ),
                ),

                // Indicateur de chargement d'adresse
                if (isLoadingAddress)
                  Positioned(
                    top: 180,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Chargement de l\'adresse...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Formulaire en bas avec défilement
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                decoration: BoxDecoration(
                  color: _c.surfaceLow,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Adresse sélectionnée
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _c.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.location_pin,
                              color: _c.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Adresse sélectionnée',
                                  style: TextStyle(
                                    color: _c.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                isLoadingAddress
                                    ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      color: _c.primary,
                                      minHeight: 2,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Chargement...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _c.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                                    : Text(
                                  displayAddress ?? 'Déplacez la carte pour choisir',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: displayAddress == null
                                        ? _c.onSurfaceVariant
                                        : _c.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Type d'adresse
                      Text(
                        'Type d\'adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _c.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTypeSelector(),

                      const SizedBox(height: 24),

                      // Nom de l'adresse
                      Text(
                        'Nom de l\'adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _c.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: _c.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Ex: Maison, Bureau, Chez Maman...',
                          hintStyle: TextStyle(color: _c.onSurfaceVariant),
                          prefixIcon: Icon(Icons.label, color: _c.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: _c.surface,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un nom';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Adresse
                      Text(
                        'Adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _c.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        style: TextStyle(color: _c.onSurface),
                        decoration: InputDecoration(
                          hintText: 'L\'adresse se remplit automatiquement depuis la carte',
                          hintStyle: TextStyle(color: _c.onSurfaceVariant),
                          prefixIcon: Icon(Icons.location_on, color: _c.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: _c.surface,
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez sélectionner une adresse sur la carte';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Détails supplémentaires
                      Text(
                        'Détails supplémentaires (optionnel)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _c.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _detailsController,
                        style: TextStyle(color: _c.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Étage, Bâtiment, Instructions...',
                          hintStyle: TextStyle(color: _c.onSurfaceVariant),
                          prefixIcon: Icon(Icons.info_outline, color: _c.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _c.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: _c.surface,
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 32),

                      // Instructions
                      if (!isLoadingAddress && _addressController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: _c.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Déplacez la carte pour ajuster l\'adresse exacte',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _c.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Bouton sauvegarder
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saveAddress,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _c.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            widget.existingAddress != null
                                ? 'Enregistrer les modifications'
                                : 'Ajouter l\'adresse',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _c.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

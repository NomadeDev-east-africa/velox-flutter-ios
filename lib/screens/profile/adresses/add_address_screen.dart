import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'package:nomade_client/services/location_service.dart';

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

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 AddAddressScreen - initState()');

    // Initialiser avec l'adresse existante si elle existe
    if (widget.existingAddress != null) {
      _initializeWithExistingLocation();
    } else {
      // Initialiser avec la position actuelle
      _initializePosition();
    }
  }

  // Initialiser avec l'adresse existante
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

      // Déplacer la carte après un délai
      _moveMapToLocation(_selectedLocation!, 16.0);
    }
  }

  // Initialiser avec la position actuelle
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

      // Déplacer la carte après un délai
      _moveMapToLocation(position, 16.0);

      debugPrint('✅ Position initialisée: $position');

      // Charger l'adresse pour cette position
      _loadAddressForPosition(position);

    } catch (e) {
      debugPrint('❌ Erreur initialisation position: $e');

      // Fallback sur position par défaut
      const defaultPosition = LatLng(11.5880, 43.1450);
      setState(() {
        _selectedLocation = defaultPosition;
        _isInitialized = true;
        _isLoadingInitialLocation = false;
      });

      // Déplacer la carte vers la position par défaut
      _moveMapToLocation(defaultPosition, 12.0);
    }
  }

  // Déplacer la carte vers une position
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

  // Charger l'adresse pour une position
  Future<void> _loadAddressForPosition(LatLng position) async {
    if (_isLoadingAddress) return;

    setState(() => _isLoadingAddress = true);

    try {
      final addr = await ref.read(locationNotifierProvider.notifier).getAddressForPosition(position);

      // Mettre à jour le champ d'adresse
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

  // Rechercher des lieux avec debouncing
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

  // Sélectionner un résultat de recherche
  void _selectSearchResult(PlaceResult place) {
    debugPrint('✅ Sélection adresse: ${place.name}');

    final position = LatLng(place.latitude, place.longitude);
    setState(() {
      _selectedLocation = position;
      _showSearchResults = false;
      _searchController.text = place.name;
    });

    // Remplir automatiquement le champ d'adresse
    _addressController.text = place.name;

    // Déplacer la carte
    _moveMapToLocation(position, 16.0);

    // Charger l'adresse
    _loadAddressForPosition(position);

    FocusScope.of(context).unfocus();
  }

  // Sélecteur de type d'adresse
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
                      ? const Color(0xFF9FFF88).withValues(alpha: 0.12)
                      : const Color(0xFF1A1919),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF9FFF88) : const Color(0xFF484847),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: isSelected ? const Color(0xFF9FFF88) : const Color(0xFFADAAAA),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF9FFF88) : const Color(0xFFADAAAA),
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

  // Sauvegarder l'adresse
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
        backgroundColor: const Color(0xFF0E0E0E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF9FFF88)),
              const SizedBox(height: 16),
              Text(
                widget.existingAddress != null
                    ? 'Chargement de l\'adresse existante...'
                    : 'Obtention de votre position...',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9FFF88),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        title: Text(
          widget.existingAddress != null ? 'Modifier l\'adresse' : 'Ajouter une adresse',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0E0E0E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMap ? Icons.light_mode : Icons.dark_mode,
              color: const Color(0xFF9FFF88),
            ),
            onPressed: () {
              setState(() => _isDarkMap = !_isDarkMap);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Carte en haut (hauteur fixe)
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

                        // Recharger l'adresse
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
                            color: const Color(0xFF9FFF88),
                            size: 50,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha:0.3),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchPlaces,
                      style: const TextStyle(fontSize: 17),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une adresse...',
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 17),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF9FFF88), size: 26),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
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
                        color: Colors.white,
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
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_searchResults.length} trouvé(s)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
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
                                  const CircularProgressIndicator(color: Color(0xFF9FFF88)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Recherche en cours...',
                                    style: TextStyle(color: Colors.grey.shade600),
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
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun résultat trouvé',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Essayez avec d\'autres termes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final place = _searchResults[index];
                                return ListTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9FFF88).withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF9FFF88),
                                      size: 26,
                                    ),
                                  ),
                                  title: Text(
                                    place.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
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
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Color(0xFF9FFF88)),
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
                          color: Colors.black.withValues(alpha:0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
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
                decoration: const BoxDecoration(
                  color: Color(0xFF131313),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
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
                              color: const Color(0xFF9FFF88).withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFF9FFF88),
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
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                isLoadingAddress
                                    ? const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      color: Color(0xFF9FFF88),
                                      minHeight: 2,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Chargement...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
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
                                        ? Colors.grey.shade500
                                        : Colors.white,
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
                      const Text(
                        'Type d\'adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTypeSelector(),

                      const SizedBox(height: 24),

                      // Nom de l'adresse
                      const Text(
                        'Nom de l\'adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ex: Maison, Bureau, Chez Maman...',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: const Icon(Icons.label, color: Color(0xFF9FFF88)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF484847)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF484847)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF9FFF88), width: 1.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A1919),
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
                      const Text(
                        'Adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'L\'adresse se remplit automatiquement depuis la carte',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: const Icon(Icons.location_on, color: Color(0xFF9FFF88)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF484847)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF484847)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF9FFF88), width: 1.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A1919),
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
                      const Text(
                        'Détails supplémentaires (optionnel)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _detailsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Étage, Bâtiment, Instructions...',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: const Icon(Icons.info_outline, color: Color(0xFF9FFF88)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF484847)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF484847)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF9FFF88), width: 1.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A1919),
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
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Déplacez la carte pour ajuster l\'adresse exacte',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
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
                            backgroundColor: const Color(0xFF9FFF88),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            widget.existingAddress != null
                                ? 'Enregistrer les modifications'
                                : 'Ajouter l\'adresse',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF026400),
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
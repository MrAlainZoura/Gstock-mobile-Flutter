import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_response.dart';
import '../../api/depot_catalog.dart';
import '../../api/reservation_service.dart';
import '../../models/depot.dart';
import '../../models/produit.dart';
import '../../models/reservation.dart';
import '../../models/vente.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';
import '../../utils/methode.dart';
import 'show.dart';

/// Création `POST /reservations`.
class ReservationCreatePage extends StatefulWidget {
  const ReservationCreatePage({super.key, required this.depot});

  final Depot depot;

  @override
  State<ReservationCreatePage> createState() => _ReservationCreatePageState();
}

class _ReservationCreatePageState extends State<ReservationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomClient = TextEditingController(text: 'Passant');
  final _contact = TextEditingController();
  final _adresse = TextEditingController();
  final _search = TextEditingController();
  final _taux = TextEditingController();
  final _trancheP = TextEditingController();
  final _numeroPiece = TextEditingController();
  String? _pieceType;
  String? _imagePath;

  String _lieu = 'Shop';
  String _query = '';
  bool _tranche = false;
  bool _prixEnCdf = false;
  bool _loadingForm = true;
  bool _saving = false;
  String? _error;

  List<_StockItem> _stock = [];
  List<_DeviseOption> _devises = [];
  _DeviseOption? _devise;
  final List<_ResaLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _prixEnCdf = widget.depot.useCdf;
    _loadForm();
  }

  @override
  void dispose() {
    _nomClient.dispose();
    _contact.dispose();
    _adresse.dispose();
    _search.dispose();
    _taux.dispose();
    _trancheP.dispose();
    _numeroPiece.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadForm() async {
    final cached = await DepotCatalogStore.read(widget.depot.id);
    if (!mounted) return;
    if (cached != null) {
      _applyPayload(cached);
      unawaited(_refreshForm());
      return;
    }
    setState(() {
      _loadingForm = true;
      _error = null;
    });
    try {
      final data = await DepotCatalogStore.fetchAndStore(widget.depot.id);
      if (!mounted) return;
      _applyPayload(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingForm = false;
      });
    }
  }

  Future<void> _refreshForm() async {
    try {
      final data = await DepotCatalogStore.fetchAndStore(widget.depot.id);
      if (!mounted) return;
      _applyPayload(data, keepUserEdits: true);
    } catch (_) {}
  }

  void _applyPayload(
    Map<String, dynamic> data, {
    bool keepUserEdits = false,
  }) {
    final depotMap = asMap(data['depot']);
    final devises = asList(data['devises']).isNotEmpty
        ? asList(data['devises'])
        : asList(depotMap?['devise'] ?? depotMap?['devises']);
    final options = devises
        .whereType<Map>()
        .map((e) => _DeviseOption.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.id > 0 && d.libele.isNotEmpty)
        .toList();
    final stock = asList(data['produits'])
        .whereType<Map>()
        .map((e) => _StockItem.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id > 0)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final useCdf = depotMap?['use_cdf'] == true ||
        depotMap?['use_cdf'] == 1 ||
        widget.depot.useCdf;
    final selected = options.isEmpty ? null : options.first;

    setState(() {
      _devises = options;
      _stock = stock;
      if (!keepUserEdits || _devise == null) {
        _devise = selected;
        _prixEnCdf = useCdf;
        _taux.text = selected == null ? '' : _plain(selected.taux);
      } else {
        final match = options.where((d) => d.id == _devise!.id);
        if (match.isNotEmpty) _devise = match.first;
      }
      _loadingForm = false;
      _error = null;
    });
  }

  num get _tauxValue {
    final value = asDouble(_taux.text.trim()) ?? 0;
    return value <= 0 ? 1 : value;
  }

  num get _net {
    return _lines.fold<num>(0, (sum, line) => sum + line.montant);
  }

  MoneyPair get _netPair {
    if (_prixEnCdf) {
      return MoneyPair(cdf: _net, devise: _net / _tauxValue);
    }
    return MoneyPair(cdf: _net * _tauxValue, devise: _net);
  }

  /// L’API stocke toujours les montants en CDF et pose
  /// `reference_devise = net / taux`. Même conversion que le web.
  num _toCdf(num amount) {
    if (_prixEnCdf) return amount;
    return amount * _tauxValue;
  }

  List<_StockItem> get _available {
    final selectedIds = _lines.map((l) => l.item.id).toSet();
    final q = _query.trim().toLowerCase();
    return _stock.where((p) {
      if (selectedIds.contains(p.id)) return false;
      if (q.isEmpty) return true;
      return p.search.contains(q);
    }).toList();
  }

  void _selectDevise(_DeviseOption? option) {
    setState(() {
      _devise = option;
      if (option != null) _taux.text = _plain(option.taux);
    });
  }

  DateTime _defaultStart() {
    final now = DateTime.now().add(const Duration(minutes: 15));
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  void _addProduct(_StockItem item) {
    final start = _defaultStart();
    final defaultMontant = _prixEnCdf
        ? (item.cdfPrix > 0 ? item.cdfPrix : item.prix)
        : (item.prix > 0 ? item.prix : item.cdfPrix);
    setState(() {
      _lines.add(
        _ResaLine(
          item: item,
          debut: start,
          fin: start.add(const Duration(hours: 1)),
          montant: defaultMontant,
        ),
      );
      _search.clear();
      _query = '';
    });
  }

  void _removeLine(_ResaLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _pickDateTime(_ResaLine line, {required bool start}) async {
    final initial = start ? line.debut : line.fin;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? initial.hour,
      time?.minute ?? initial.minute,
    );
    setState(() {
      if (start) {
        line.debut = picked;
        if (!line.fin.isAfter(line.debut)) {
          line.fin = line.debut.add(const Duration(hours: 1));
        }
      } else {
        line.fin = picked;
      }
    });
  }

  Future<void> _pickImageSource() async {
    if (_saving) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Photo de la pièce d'identité",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Caméra, galerie ou stockage — accès demandé à l'ouverture.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.white,
                    child: Icon(Icons.photo_camera_outlined),
                  ),
                  title: const Text('Prendre une photo'),
                  subtitle: const Text('Accès caméra'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    child: Icon(Icons.photo_library_outlined),
                  ),
                  title: const Text('Galerie / stockage'),
                  subtitle: const Text('Accès photos et fichiers'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                if (_imagePath != null)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.red,
                      foregroundColor: AppColors.white,
                      child: Icon(Icons.delete_outline),
                    ),
                    title: const Text('Retirer la photo'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _imagePath = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        // Sous upload_max_filesize PHP (~2 Mo) : compression agressive.
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (file == null || !mounted) return;
      setState(() => _imagePath = file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(
            source == ImageSource.camera
                ? "Impossible d'accéder à la caméra. Vérifiez les permissions."
                : "Impossible d'accéder à la galerie/stockage. Vérifiez les permissions.",
          ),
        ),
      );
    }
  }

  Widget _buildPiecePhotoPicker() {
    final hasImage = _imagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Photo pièce d'identité (optionnel)",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.grayLight,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _saving ? null : _pickImageSource,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasImage
                      ? AppColors.blue.withValues(alpha: 0.55)
                      : AppColors.gray.withValues(alpha: 0.35),
                  width: hasImage ? 1.5 : 1,
                ),
              ),
              child: hasImage
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.file(
                            File(_imagePath!),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              alignment: Alignment.center,
                              color: AppColors.grayLight,
                              child: const Text(
                                'Aperçu indisponible',
                                style: TextStyle(color: AppColors.gray),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(13),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.black.withValues(alpha: 0),
                                  AppColors.black.withValues(alpha: 0.65),
                                ],
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.zoom_out_map,
                                  size: 16,
                                  color: AppColors.white,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Aperçu — toucher pour changer',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: AppColors.black.withValues(alpha: 0.55),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Retirer',
                              visualDensity: VisualDensity.compact,
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _imagePath = null),
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.blue.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.badge_outlined,
                              color: AppColors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ajouter une photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Caméra · Galerie · Stockage',
                            style: TextStyle(
                              color: AppColors.gray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImageSource,
                  icon: const Icon(Icons.cameraswitch_outlined, size: 18),
                  label: const Text('Changer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _imagePath = null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Retirer'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez au moins un produit")),
      );
      return;
    }
    if (_devise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisissez une devise")),
      );
      return;
    }
    for (final line in _lines) {
      if (line.montant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Montant requis pour ${line.item.name}")),
        );
        return;
      }
      if (!line.fin.isAfter(line.debut)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("La fin doit être après le début (${line.item.name})"),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final reservations = <String, Map<String, dynamic>>{};
      for (final line in _lines) {
        reservations['${line.item.id}'] = {
          'startAt': _apiDateTime(line.debut),
          'endAt': _apiDateTime(line.fin),
          'montant': _toCdf(line.montant),
        };
      }
      final created = await ReservationService().create(
        ReservationCreatePayload(
          depotId: widget.depot.id,
          lieuDeVente: _lieu,
          nomClient: _nomClient.text.trim().isEmpty
              ? 'Passant'
              : _nomClient.text.trim(),
          contactClient: _contact.text.trim(),
          adresse: _adresse.text.trim(),
          monnaie: '${_devise!.id}-${_devise!.libele}',
          updateDevise: _tauxValue,
          tranche: _tranche,
          trancheP: _toCdf(num.tryParse(_trancheP.text.trim()) ?? 0),
          reservations: reservations,
          piece: _pieceType,
          numeroPiece: _numeroPiece.text.trim().isEmpty
              ? null
              : _numeroPiece.text.trim(),
          imagePath: _imagePath,
        ),
      );
      unawaited(DepotCatalogStore.refreshInBackground(widget.depot.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Réservation enregistrée")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReservationShowPage(
            reservationId: created.id,
            depot: widget.depot,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(e.message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text("Nouvelle réservation — ${widget.depot.libele}"),
      ),
      body: _loadingForm
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Erreur: $_error"),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadForm,
                          child: const Text("Réessayer"),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _section(
                        title: "Client",
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nomClient,
                              decoration: const InputDecoration(
                                labelText: "Nom client",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _contact,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Téléphone",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _adresse,
                              decoration: const InputDecoration(
                                labelText: "Adresse",
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_pieceType ?? ''),
                              initialValue: _pieceType ?? '',
                              decoration: const InputDecoration(
                                labelText: "Pièce d'identité (optionnel)",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('— Aucune —'),
                                ),
                                DropdownMenuItem(
                                  value: 'Carte d\'électeur',
                                  child: Text("Carte d'électeur"),
                                ),
                                DropdownMenuItem(
                                  value: 'Passeport',
                                  child: Text('Passeport'),
                                ),
                                DropdownMenuItem(
                                  value: 'Permis de conduire',
                                  child: Text('Permis de conduire'),
                                ),
                                DropdownMenuItem(
                                  value: 'Autre',
                                  child: Text('Autre'),
                                ),
                              ],
                              onChanged: (v) => setState(() => _pieceType = (v == null || v.isEmpty) ? null : v),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _numeroPiece,
                              decoration: const InputDecoration(
                                labelText: "N° pièce (optionnel)",
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPiecePhotoPicker(),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_lieu),
                              initialValue: _lieu,
                              decoration: const InputDecoration(
                                labelText: "Lieu",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Shop',
                                  child: Text('Au shop'),
                                ),
                                DropdownMenuItem(
                                  value: 'Livraison',
                                  child: Text('Livraison'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _lieu = v ?? 'Shop'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        title: "Devise et taux",
                        child: Column(
                          children: [
                            DropdownButtonFormField<_DeviseOption>(
                              key: ValueKey(_devise?.id),
                              initialValue: _devise != null &&
                                      _devises.any((d) => d.id == _devise!.id)
                                  ? _devises.firstWhere(
                                      (d) => d.id == _devise!.id,
                                    )
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Devise",
                              ),
                              items: _devises
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        "${d.libele}  ·  1 ${d.libele} = ${formatMoney(d.taux)} CDF",
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _selectDevise,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _taux,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    "Taux (1 ${_devise?.libele ?? 'devise'} = ? CDF)",
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = asDouble(v);
                                if (n == null || n <= 0) {
                                  return "Taux invalide";
                                }
                                return null;
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Montants saisis en CDF"),
                              subtitle: Text(
                                _prixEnCdf
                                    ? "Le montant est en francs congolais"
                                    : "Le montant est en ${_devise?.libele ?? 'devise'}",
                                style: const TextStyle(color: AppColors.gray),
                              ),
                              value: _prixEnCdf,
                              onChanged: (v) => setState(() => _prixEnCdf = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        title: "Produits",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _search,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                hintText: "Rechercher un produit à ajouter",
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _search.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_query.trim().isEmpty)
                              const Text(
                                "Tapez pour rechercher un produit",
                                style: TextStyle(color: AppColors.gray),
                              )
                            else if (_available.isEmpty)
                              Text(
                                _stock.isEmpty
                                    ? "Aucun produit en stock"
                                    : "Aucun produit à ajouter",
                                style: const TextStyle(color: AppColors.gray),
                              )
                            else
                              ..._available.take(3).map(
                                    (p) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.add_circle_outline,
                                        color: AppColors.blue,
                                      ),
                                      title: Text(p.name),
                                      subtitle: Text(
                                        "Stock ${p.stock} ${p.unite}",
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      onTap: () => _addProduct(p),
                                    ),
                                  ),
                            if (_lines.isNotEmpty) ...[
                              const Divider(),
                              const Text(
                                "Produits sélectionnés",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              ..._lines.map(_lineCard),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _netPreview(),
                      const SizedBox(height: 12),
                      _section(
                        title: "Paiement",
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Paiement par tranche"),
                              value: _tranche,
                              onChanged: (v) => setState(() => _tranche = v),
                            ),
                            if (_tranche)
                              TextFormField(
                                controller: _trancheP,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      "Avance (${_prixEnCdf ? 'CDF' : (_devise?.libele ?? 'devise')})",
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text("Enregistrer la réservation"),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _datePickButton({
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                formatDateTimeFr(value),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(_ResaLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: () => _removeLine(line),
                  icon: const Icon(Icons.close, color: AppColors.red),
                ),
              ],
            ),
            _datePickButton(
              label: 'Début',
              value: line.debut,
              icon: Icons.play_arrow,
              onPressed: () => _pickDateTime(line, start: true),
            ),
            const SizedBox(height: 8),
            _datePickButton(
              label: 'Fin',
              value: line.fin,
              icon: Icons.stop,
              onPressed: () => _pickDateTime(line, start: false),
            ),
            const SizedBox(height: 8),
            Text(
              "Période ${formatPeriode(line.debut, line.fin)}",
              style: const TextStyle(color: AppColors.gray),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: line.montantCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    "Montant (${_prixEnCdf ? 'CDF' : (_devise?.libele ?? '')})",
              ),
              onChanged: (v) {
                setState(() => line.montant = asDouble(v) ?? 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _netPreview() {
    final pair = _netPair;
    final libele = _devise?.libele ?? 'USD';
    return Card(
      color: AppColors.black,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Aperçu — net à payer",
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${formatMoney(pair.devise)} $libele",
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${formatMoney(pair.cdf)} CDF",
              style: const TextStyle(color: AppColors.gray, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              "1 $libele = ${formatMoney(_tauxValue)} CDF · ${_lines.length} produit(s)",
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeviseOption {
  _DeviseOption({required this.id, required this.libele, required this.taux});

  final int id;
  final String libele;
  final num taux;

  factory _DeviseOption.fromJson(Map<String, dynamic> json) {
    return _DeviseOption(
      id: asInt(json['id']),
      libele: json['libele']?.toString() ?? '',
      taux: asDouble(json['taux']) ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _DeviseOption && other.id == id && other.libele == libele;

  @override
  int get hashCode => Object.hash(id, libele);
}

class _StockItem {
  _StockItem({
    required this.id,
    required this.name,
    required this.stock,
    required this.unite,
    required this.prix,
    required this.cdfPrix,
    required this.search,
  });

  final int id;
  final String name;
  final int stock;
  final String unite;
  final num prix;
  final num cdfPrix;
  final String search;

  factory _StockItem.fromJson(Map<String, dynamic> json) {
    final nested = asMap(json['produit']) ?? json;
    final produit = Produit.fromJson(nested);
    final marque = produit.marque?.trim() ?? '';
    final name = [
      if (marque.isNotEmpty) marque,
      produit.libele,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    return _StockItem(
      id: produit.id > 0 ? produit.id : asInt(json['produit_id']),
      name: name.isEmpty ? 'Produit' : name,
      stock: asInt(json['quantite'] ?? json['quatité'] ?? produit.quantite),
      unite: (produit.unite != null && produit.unite!.isNotEmpty)
          ? produit.unite!
          : 'pcs',
      prix: asDouble(produit.prix) ?? 0,
      cdfPrix: asDouble(json['cdf_prix']) ?? 0,
      search: [
        name,
        produit.categorie ?? '',
        produit.description,
      ].join(' ').toLowerCase(),
    );
  }
}

class _ResaLine {
  _ResaLine({
    required this.item,
    required this.debut,
    required this.fin,
    required num montant,
  })  : montantCtrl = TextEditingController(text: _plain(montant)),
        montant = montant;

  final _StockItem item;
  final TextEditingController montantCtrl;
  DateTime debut;
  DateTime fin;
  num montant;

  void dispose() {
    montantCtrl.dispose();
  }
}

String _plain(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}

String _apiDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:00';
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_response.dart';
import '../../api/client_service.dart';
import '../../models/client.dart';
import '../../models/depot.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Mise à jour infos client + pièce d'identité (`PUT/POST /clients/{id}`).
class ClientEditPage extends StatefulWidget {
  const ClientEditPage({
    super.key,
    required this.depot,
    required this.clientId,
  });

  final Depot depot;
  final int clientId;

  @override
  State<ClientEditPage> createState() => _ClientEditPageState();
}

class _ClientEditPageState extends State<ClientEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _prenom = TextEditingController();
  final _tel = TextEditingController();
  final _adresse = TextEditingController();
  final _numeroPiece = TextEditingController();
  String _genre = 'M';
  String? _pieceType;
  String? _imagePath;
  String? _remoteImage;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _pieceOptions = [
    "Carte d'électeur",
    'Passeport',
    'Permis de conduire',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _prenom.dispose();
    _tel.dispose();
    _adresse.dispose();
    _numeroPiece.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = await ClientService().getForEdit(
        widget.clientId,
        widget.depot.id,
      );
      if (!mounted) return;
      final raw = client.pieceIdentite?.trim();
      String? piece;
      if (raw != null && raw.isNotEmpty) {
        piece = _pieceOptions.contains(raw) ? raw : 'Autre';
      }
      setState(() {
        _name.text = client.name ?? '';
        _prenom.text = client.prenom ?? '';
        _tel.text = client.tel ?? '';
        _adresse.text = client.adresse ?? '';
        _pieceType = piece;
        _numeroPiece.text = client.numeroPiece ?? '';
        _genre = (client.genre == 'F') ? 'F' : 'M';
        _remoteImage = client.imagePiece;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
                if (_imagePath != null ||
                    (_remoteImage != null && _remoteImage!.isNotEmpty))
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.red,
                      foregroundColor: AppColors.white,
                      child: Icon(Icons.delete_outline),
                    ),
                    title: const Text('Retirer la photo'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imagePath = null;
                        _remoteImage = null;
                      });
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
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (file == null || !mounted) return;
      setState(() => _imagePath = file.path);
    } catch (_) {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = Client(
        id: widget.clientId,
        name: _name.text.trim(),
        prenom: _prenom.text.trim(),
        tel: _tel.text.trim(),
        adresse: _adresse.text.trim(),
        genre: _genre,
        pieceIdentite: _pieceType,
        numeroPiece: _numeroPiece.text.trim().isEmpty
            ? null
            : _numeroPiece.text.trim(),
      );
      await ClientService().update(
        widget.clientId,
        client,
        depotId: widget.depot.id,
        imagePath: _imagePath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client mis à jour')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildPiecePhotoPicker() {
    final remoteUrl = uploadsUrl('pieceIdentite', _remoteImage);
    final hasLocal = _imagePath != null;
    final hasRemote = !hasLocal && remoteUrl.isNotEmpty;
    final hasImage = hasLocal || hasRemote;

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
                          child: hasLocal
                              ? Image.file(
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
                                )
                              : Image.network(
                                  remoteUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 180,
                                    alignment: Alignment.center,
                                    color: AppColors.grayLight,
                                    child: const Text(
                                      'Image indisponible',
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
                                  : () => setState(() {
                                        _imagePath = null;
                                        _remoteImage = null;
                                      }),
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
                  : const SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: AppColors.blue,
                            size: 28,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Ajouter une photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
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
                      : () => setState(() {
                            _imagePath = null;
                            _remoteImage = null;
                          }),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(title: const Text('Modifier client')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Nom *',
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Requis'
                                        : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _prenom,
                                decoration: const InputDecoration(
                                  labelText: 'Prénom',
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                key: ValueKey(_genre),
                                initialValue: _genre,
                                decoration: const InputDecoration(
                                  labelText: 'Genre',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'M',
                                    child: Text('Masculin'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'F',
                                    child: Text('Féminin'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _genre = v ?? 'M'),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _tel,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Téléphone',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _adresse,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Adresse',
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
                                    value: "Carte d'électeur",
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
                                onChanged: (v) => setState(
                                  () => _pieceType =
                                      (v == null || v.isEmpty) ? null : v,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _numeroPiece,
                                decoration: const InputDecoration(
                                  labelText: 'N° pièce (optionnel)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildPiecePhotoPicker(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                              : const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

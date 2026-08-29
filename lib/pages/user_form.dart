import 'package:flutter/material.dart';

import '../api/api_response.dart';
import '../api/auth_service.dart';
import '../api/dashboard_service.dart';
import '../api/user_service.dart';
import '../models/depot.dart';
import '../utils/access.dart';
import '../utils/app_theme.dart';

/// Formulaire create `POST /users` / update `PUT /users/{id}`.
/// Create & update (admin) : affectations PDV via `depot_id` / `affectation[]`.
class UserFormScreen extends StatefulWidget {
  final int? userId;
  /// Point de vente courant — requis pour la création / affectations admin.
  final int? depotId;

  const UserFormScreen({super.key, this.userId, this.depotId});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _postnomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: '0000');
  final _telController = TextEditingController();
  final _fonctionController = TextEditingController();
  final _adresseController = TextEditingController();
  final _naissanceController = TextEditingController();
  final _niveauController = TextEditingController();
  final _optionController = TextEditingController();
  String _genre = 'M';
  bool _loading = false;
  bool _loadingUser = false;
  bool _loadingDepots = false;
  Access _access = Access();

  List<Depot> _assignableDepots = [];
  final Set<int> _selectedDepotIds = {};

  bool get _isCreate => widget.userId == null;
  bool get _canEditAffectation => _access.isAdmin && widget.depotId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _access = await Access.load();
    if (!mounted) return;
    if (widget.userId != null) {
      setState(() => _loadingUser = true);
      try {
        final user = await UserService().getUserById(widget.userId!);
        if (!mounted) return;
        setState(() {
          _nameController.text = user.name;
          _postnomController.text = user.postnom ?? '';
          _prenomController.text = user.prenom ?? '';
          _emailController.text = user.email;
          _telController.text = user.tel ?? '';
          _fonctionController.text = user.fonction ?? '';
          _adresseController.text = user.adresse ?? '';
          _naissanceController.text = user.naissance ?? '';
          _niveauController.text = user.niveauEtude ?? '';
          _optionController.text = user.option ?? '';
          if (user.genre != null && user.genre!.isNotEmpty) {
            _genre = user.genre!;
          }
          for (final row in user.depotUser) {
            if (row.depotId > 0) _selectedDepotIds.add(row.depotId);
          }
          _loadingUser = false;
        });
        if (_canEditAffectation) await _loadAssignableDepots();
      } catch (_) {
        if (mounted) setState(() => _loadingUser = false);
      }
    } else if (widget.depotId != null) {
      await _loadAssignableDepots();
    }
  }

  Future<void> _loadAssignableDepots() async {
    final currentId = widget.depotId;
    if (currentId == null) return;
    setState(() => _loadingDepots = true);
    try {
      final access = await Access.load();
      final dash = await DashboardService().getDashboard();
      final all = dash.depots;
      final visible = access.visibleDepots(all);
      Depot? current;
      for (final d in [...visible, ...all]) {
        if (d.id == currentId) {
          current = d;
          break;
        }
      }
      if (current == null) {
        if (!mounted) return;
        setState(() {
          _assignableDepots = [];
          if (_isCreate) {
            _selectedDepotIds
              ..clear()
              ..add(currentId);
          }
          _loadingDepots = false;
        });
        return;
      }

      final ownerId = current.userId;
      final source = access.isSuperAdmin ? all : visible;
      final assignable = source
          .where((d) => d.userId == ownerId || d.id == currentId)
          .toList()
        ..sort((a, b) => a.libele.compareTo(b.libele));

      if (!mounted) return;
      setState(() {
        _assignableDepots = assignable.isEmpty ? [current!] : assignable;
        if (_isCreate) {
          _selectedDepotIds
            ..clear()
            ..add(currentId);
        } else {
          // Garder les sélections existantes qui sont encore autorisées.
          _selectedDepotIds.removeWhere(
            (id) => !_assignableDepots.any((d) => d.id == id),
          );
          if (widget.depotId != null) {
            _selectedDepotIds.add(widget.depotId!);
          }
        }
        _loadingDepots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_isCreate) {
          _selectedDepotIds
            ..clear()
            ..add(currentId);
        }
        _loadingDepots = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final access = await Access.load();
    if (_isCreate && !access.canCreateUser) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous ne disposez pas de droit nécessaire pour effectuer cette action !',
          ),
        ),
      );
      return;
    }
    if (!_isCreate && !access.canEditUser(widget.userId!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modification de profil non autorisée')),
      );
      return;
    }
    if (_isCreate && widget.depotId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Point de vente requis pour créer un utilisateur'),
        ),
      );
      return;
    }
    if (_canEditAffectation && widget.depotId != null) {
      _selectedDepotIds.add(widget.depotId!);
    }

    setState(() => _loading = true);
    try {
      if (_isCreate) {
        await UserService().createUser({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.isEmpty
              ? '0000'
              : _passwordController.text,
          'genre': _genre,
          'naissance': _naissanceController.text.trim(),
          'fonction': _fonctionController.text.trim(),
          'niveauEtude': _niveauController.text.trim(),
          'option': _optionController.text.trim(),
          'adresse': _adresseController.text.trim(),
          'tel': _telController.text.trim(),
          'postnom': _postnomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'depot_id': widget.depotId,
          'affectation': _selectedDepotIds.toList(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilisateur créé (rôle user + affectations)'),
          ),
        );
      } else {
        final body = <String, dynamic>{
          'id': widget.userId,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'genre': _genre,
          'naissance': _naissanceController.text.trim(),
          'fonction': _fonctionController.text.trim(),
          'niveauEtude': _niveauController.text.trim(),
          'option': _optionController.text.trim(),
          'tel': _telController.text.trim(),
          'adresse': _adresseController.text.trim(),
          'postnom': _postnomController.text.trim(),
          'prenom': _prenomController.text.trim(),
        };
        if (_canEditAffectation) {
          body['depot_id'] = widget.depotId;
          body['affectation'] = _selectedDepotIds.toList();
        }
        final updated = await UserService().updateUser(widget.userId!, body);
        final session = await AuthService().user();
        if (session != null && session.id == updated.id) {
          try {
            await AuthService().me();
          } catch (_) {}
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour')),
        );
      }
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _postnomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telController.dispose();
    _fonctionController.dispose();
    _adresseController.dispose();
    _naissanceController.dispose();
    _niveauController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  Widget _affectationSection() {
    return _section(
      title: 'Affectation',
      children: [
        const Text(
          'Points de vente de l’admin du PDV courant '
          '(le PDV en cours reste sélectionnable) :',
          style: TextStyle(fontSize: 13, color: AppColors.gray),
        ),
        const SizedBox(height: 8),
        if (_loadingDepots)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_assignableDepots.isEmpty)
          Text(
            'PDV courant #${widget.depotId}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
        else
          ..._assignableDepots.map((d) {
            final checked = _selectedDepotIds.contains(d.id);
            final isCurrent = d.id == widget.depotId;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: checked,
              title: Text(
                '${d.type} ${d.libele}'.trim(),
                style: TextStyle(
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle:
                  isCurrent ? const Text('Point de vente en cours') : null,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedDepotIds.add(d.id);
                  } else if (!isCurrent || !_isCreate) {
                    // En création, le PDV courant reste obligatoire.
                    if (isCurrent && _isCreate) return;
                    _selectedDepotIds.remove(d.id);
                  }
                });
              },
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text(_isCreate ? 'Créer utilisateur' : 'Modifier profil'),
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _section(
                    title: 'Identité',
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Nom requis'
                                : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _postnomController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Postnom',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _prenomController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Prénom',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_genre),
                        initialValue: _genre,
                        decoration: const InputDecoration(
                          labelText: 'Genre',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text('Masculin')),
                          DropdownMenuItem(value: 'F', child: Text('Féminin')),
                        ],
                        onChanged: (v) => setState(() => _genre = v ?? 'M'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _naissanceController,
                        decoration: const InputDecoration(
                          labelText: 'Date de naissance',
                          hintText: 'AAAA-MM-JJ',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'Coordonnées',
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email requis';
                          }
                          if (!value.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _telController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          hintText: '+243 …',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _adresseController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'Profession',
                    children: [
                      TextFormField(
                        controller: _fonctionController,
                        decoration: const InputDecoration(
                          labelText: 'Fonction',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _niveauController,
                        decoration: const InputDecoration(
                          labelText: "Niveau d'étude",
                          hintText: 'D6, G3, L2, Master…',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _optionController,
                        decoration: const InputDecoration(
                          labelText: 'Option / filière',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                    ],
                  ),
                  if (_canEditAffectation) ...[
                    const SizedBox(height: 12),
                    _affectationSection(),
                  ],
                  if (_isCreate) ...[
                    const SizedBox(height: 12),
                    _section(
                      title: 'Sécurité',
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe * (défaut 0000)',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (!_isCreate) return null;
                            if (value == null || value.isEmpty) return null;
                            if (value.length < 4) {
                              return 'Mot de passe trop court';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              _isCreate
                                  ? 'Créer'
                                  : 'Enregistrer les modifications',
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

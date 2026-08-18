import '../mapper/user_mapper.dart';
import '../models/user.dart';
import 'api_client.dart';

/// `apiResource /users` + routes dépôt / mot de passe.
class UserService {
  final ApiClient _api = ApiClient.instance;

  Future<List<User>> getAllUsers() async {
    final res = await _api.get('users');
    return UserMapper.fromJsonList(res.data);
  }

  Future<User> getUserById(int id) async {
    final res = await _api.get('users/$id');
    return UserMapper.fromJsonSingle({'data': res.data});
  }

  /// `GET /users/depot/{depot}` — utilisateurs affectés au dépôt.
  Future<List<User>> getUsersByDepot(int depotId) async {
    final res = await _api.get('users/depot/$depotId');
    return UserMapper.fromJsonList(res.data);
  }

  /// `POST /users` — name, email, password obligatoires.
  Future<User> createUser(Map<String, dynamic> userData) async {
    final res = await _api.post('users', body: userData);
    return UserMapper.fromJsonSingle({'data': res.data});
  }

  /// `PUT /users/{id}` — sans password ; name, email, id requis.
  Future<User> updateUser(int id, Map<String, dynamic> userData) async {
    final payload = {...userData, 'id': id};
    final res = await _api.put('users/$id', body: payload);
    return UserMapper.fromJsonSingle({'data': res.data});
  }

  Future<void> deleteUser(int id) async {
    await _api.delete('users/$id');
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/router/access_control.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/contacts_remote_datasource.dart';
import '../../data/models/company_contact.dart';

final contactsDatasourceProvider =
    Provider.autoDispose<ContactsRemoteDatasource>((ref) => ContactsRemoteDatasource(ref.watch(dioProvider)));

/// The Contact Matrix as the server scopes it for this user.
final contactMatrixProvider = FutureProvider.autoDispose<ContactMatrix>(
  (ref) => ref.watch(contactsDatasourceProvider).fetch(),
);

/// Branch choices for the add/edit form — only fetched when the form opens.
final contactBranchesProvider = FutureProvider.autoDispose<List<ContactBranchOption>>(
  (ref) => ref.watch(contactsDatasourceProvider).fetchBranches(),
);

/// What this user may do in the Contact Matrix. Add follows the server's
/// `can_manage` (documents.create), as on web. Edit and Delete also need the
/// codename their endpoint checks (documents.edit / documents.delete); web
/// shows both on can_manage alone, which can offer a button the server then
/// refuses.
({bool add, bool edit, bool delete}) contactActions(ContactMatrix matrix, UserEntity? user) => (
      add: matrix.canManage,
      edit: matrix.canManage && userHasPermission(user, 'documents.edit'),
      delete: matrix.canManage && userHasPermission(user, 'documents.delete'),
    );

/// Add / edit / remove. Each returns null on success or the server's
/// message; the list is reloaded after a change.
class ContactActions {
  ContactActions(this._ref);
  final Ref _ref;

  Future<String?> _run(Future<void> Function(ContactsRemoteDatasource ds) action) async {
    try {
      await action(_ref.read(contactsDatasourceProvider));
      _ref.invalidate(contactMatrixProvider);
      return null;
    } catch (e) {
      return userFriendlyMessage(e);
    }
  }

  Future<String?> save(int? id, ContactForm form) {
    final problem = contactFormError(form);
    if (problem != null) return Future.value(problem);
    return _run((ds) => id == null ? ds.create(form) : ds.update(id, form));
  }

  Future<String?> remove(int id) => _run((ds) => ds.delete(id));
}

// Not autoDispose: an action's Ref must outlive the tap that started it.
final contactActionsProvider = Provider<ContactActions>((ref) => ContactActions(ref));

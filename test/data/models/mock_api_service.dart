import 'user.dart';
import 'create_user_request.dart';
import 'update_user_request.dart';
import 'paged_response.dart';
import 'page_args.dart';

// Mock API Service interface used across tests
abstract class MockApiService {
  Future<User> getUser(int id);
  Future<List<User>> getUsers();
  Future<User> createUser(CreateUserRequest? request);
  Future<User> updateUser(UpdateUserRequest? request);
  Future<void> deleteUser(int id);
  Future<PagedResponse> getUsersPage(PageArgs? args);
}

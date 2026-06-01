import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import '../models/trivia_category.dart';

class TriviaException implements Exception {
  final String message;
  const TriviaException(this.message);

  @override
  String toString() => 'TriviaException: $message';
}

class TriviaService {
  static const _base = 'https://opentdb.com';

  String? _token;

  Future<List<TriviaCategory>> fetchCategories() async {
    final uri = Uri.parse('$_base/api_category.php');
    final response = await http.get(uri);
    _assertHttpOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['trivia_categories'] as List;
    return list
        .map((e) => TriviaCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryQuestionCount> fetchCategoryCount(int categoryId) async {
    final uri = Uri.parse('$_base/api_count.php?category=$categoryId');
    final response = await http.get(uri);
    _assertHttpOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CategoryQuestionCount.fromJson(data);
  }

  // categoryId null = any category (omits the parameter from the request)
  Future<List<QuestionModel>> fetchQuestions({
    int? categoryId,
    String difficulty = 'any',
    String type = 'any',
    int amount = 10,
  }) {
    return _doFetch(
      categoryId: categoryId,
      difficulty: difficulty,
      type: type,
      amount: amount,
      retry: true,
    );
  }

  Future<List<QuestionModel>> _doFetch({
    required int? categoryId,
    required String difficulty,
    required String type,
    required int amount,
    required bool retry,
  }) async {
    await _ensureToken();

    final params = <String, String>{
      'amount': '$amount',
      'token': _token!,
      if (categoryId != null) 'category': '$categoryId',
      if (difficulty != 'any') 'difficulty': difficulty,
      if (type != 'any') 'type': type,
    };

    final uri = Uri.parse('$_base/api.php').replace(queryParameters: params);
    final response = await http.get(uri);
    _assertHttpOk(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['response_code'] as int;

    if (retry) {
      if (code == 3) {
        // Token expired — re-request and retry once
        _token = null;
        return _doFetch(
          categoryId: categoryId,
          difficulty: difficulty,
          type: type,
          amount: amount,
          retry: false,
        );
      }
      if (code == 4) {
        // Token exhausted — reset and retry once
        await _resetToken();
        return _doFetch(
          categoryId: categoryId,
          difficulty: difficulty,
          type: type,
          amount: amount,
          retry: false,
        );
      }
    }

    _assertResponseCode(code);

    final results = data['results'] as List;
    return results
        .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _ensureToken() async {
    if (_token != null) return;
    final uri = Uri.parse('$_base/api_token.php?command=request');
    final response = await http.get(uri);
    _assertHttpOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['token'] as String;
  }

  Future<void> _resetToken() async {
    final uri = Uri.parse('$_base/api_token.php?command=reset&token=$_token');
    final response = await http.get(uri);
    _assertHttpOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['token'] as String;
  }

  void _assertHttpOk(http.Response response) {
    if (response.statusCode != 200) {
      throw TriviaException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      );
    }
  }

  void _assertResponseCode(int code) {
    switch (code) {
      case 0:
        return;
      case 1:
        throw const TriviaException(
          'Not enough questions available for the selected filters.',
        );
      case 2:
        throw const TriviaException('Invalid parameters sent to the API.');
      case 5:
        throw const TriviaException(
          'Rate limited by OpenTDB. Please wait a moment before retrying.',
        );
      default:
        throw TriviaException('Unexpected API response code: $code.');
    }
  }
}

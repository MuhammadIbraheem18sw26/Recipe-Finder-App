import 'package:flutter/material.dart';
import 'package:http/http.dart';

const String apiKey = '389935083475c2d30d934d840eca59be';
const String apiId = '897eb0fc';
const String apiUrl = 'https://api.edamam.com/search';

class RecipeService {
  Future getData(String url) async {
    print('Calling $url');

    final response = await get(Uri.parse(url));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      print(response.statusCode);
    }
  }

  Future<dynamic> getRecipes(String query, int from, int to) async {
    final recipeData = await getData(
        '$apiUrl?app_id=$apiId&app_key=$apiKey&q=$query&from=$from&to=$to');
    return recipeData;
  }
}

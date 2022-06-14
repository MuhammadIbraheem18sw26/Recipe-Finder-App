import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/custom_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../colors.dart';
import '../../network/recipe_model.dart';
import 'package:flutter/services.dart';
import '../recipe_card.dart';
import 'recipe_details.dart';
import '../../network/recipe_service.dart';
import 'package:chopper/chopper.dart';
import '../../network/model_response.dart';

class RecipeList extends StatefulWidget {
  const RecipeList({Key? key}) : super(key: key);

  @override
  _RecipeListState createState() => _RecipeListState();
}

class _RecipeListState extends State<RecipeList> {
  static const _prefSearchKey = 'previousSearches';
  late TextEditingController searchTextController;
  final ScrollController _scrollController = ScrollController();
  List<APIHits> currentSearchList = [];
  int currentCount = 0;
  int currentStartPosition = 0;
  int currentEndPosition = 20;
  int pageCount = 20;
  bool hasMore = false;
  bool loading = false;
  bool inErrorState = false;

  List<String> previousSearches = <String>[];

  @override
  void initState() {
    super.initState();
    getPreviousSearches();
    searchTextController = TextEditingController(text: '');
    _scrollController
      ..addListener(() {
        final triggerFetchMoreSize =
            0.7 * _scrollController.position.maxScrollExtent;

        if (_scrollController.position.pixels > triggerFetchMoreSize) {
          if (hasMore &&
              currentEndPosition < currentCount &&
              !loading &&
              !inErrorState) {
            setState(() {
              loading = true;
              currentStartPosition = currentEndPosition;
              currentEndPosition =
                  min(currentStartPosition + pageCount, currentCount);
            });
          }
        }
      });
  }

  @override
  void dispose() {
    searchTextController.dispose();
    super.dispose();
  }

  void savePreviousSearches() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(_prefSearchKey, previousSearches);
  }

  void getPreviousSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_prefSearchKey)) {
      previousSearches = prefs.getStringList(_prefSearchKey) ?? <String>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSearchCard(),
            _buildRecipeLoader(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 4,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0))),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                startSearch(searchTextController.text);
                final currentFocus = FocusScope.of(context);
                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
              },
            ),
            const SizedBox(
              width: 6.0,
            ),

            Expanded(
                child: TextField(
              decoration: const InputDecoration(
                  border: InputBorder.none, hintText: 'Search'),
              autofocus: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (!previousSearches.contains(value)) {
                  previousSearches.add(value);
                  savePreviousSearches();
                }
              },
              controller: searchTextController,
            )),
// 6
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.arrow_drop_down,
                color: lightGrey,
              ),
              // 7
              onSelected: (String value) {
                searchTextController.text = value;
                startSearch(searchTextController.text);
              },
              itemBuilder: (BuildContext context) {
                // 8
                return previousSearches
                    .map<CustomDropdownMenuItem<String>>((String value) {
                  return CustomDropdownMenuItem<String>(
                    text: value,
                    value: value,
                    callback: () {
                      setState(() {
                        // 9
                        previousSearches.remove(value);
                        Navigator.pop(context);
                      });
                    },
                  );
                }).toList();
              },
            ),
            // *** End Replace
          ],
        ),
      ),
    );
  }

  void startSearch(String value) {
    setState(() {
      currentSearchList.clear();
      currentCount = 0;
      currentEndPosition = pageCount;
      currentStartPosition = 0;
      hasMore = true;
      if (previousSearches.contains(value)) {
        previousSearches.add(value);
        savePreviousSearches();
      }
    });
  }

  Widget _buildRecipeLoader(BuildContext context) {
    if (searchTextController.text.length < 3) {
      return Container();
    }

    return FutureBuilder<Response<Result<APIRecipeQuery>>>(
      future: RecipeService.create().queryRecipes(
          searchTextController.text.trim(),
          currentStartPosition,
          currentEndPosition),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString(),
                  textAlign: TextAlign.center, textScaleFactor: 1.3),
            );
          }

          loading = false;
          final result = snapshot.data?.body;
// 2
          if (result is Error) {
            // Hit an error
            inErrorState = true;
            return _buildRecipeList(context, currentSearchList);
          }
// 3
          final query = (result as Success).value;
          inErrorState = false;
          if (query != null) {
            currentCount = query.count;
            hasMore = query.more;
            currentSearchList.addAll(query.hits);
            // 8
            if (query.to < currentEndPosition) {
              currentEndPosition = query.to;
            }
          }
          // 9
          return _buildRecipeList(context, currentSearchList);
        } else {
          // 11
          if (currentCount == 0) {
            // Show a loading indicator while waiting for the recipes
            return const Center(child: CircularProgressIndicator());
          } else {
            // 12
            return _buildRecipeList(context, currentSearchList);
          }
        }
      },
    );
  }

  Widget _buildRecipeList(BuildContext recipeListContext, List<APIHits> hits) {
    // 2
    final size = MediaQuery.of(context).size;
    const itemHeight = 310;
    final itemWidth = size.width / 2;
    // 3
    return Flexible(
      // 4
      child: GridView.builder(
        // 5
        controller: _scrollController,
        // 6
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: (itemWidth / itemHeight),
        ),
        // 7
        itemCount: hits.length,
        // 8
        itemBuilder: (BuildContext context, int index) {
          return _buildRecipeCard(recipeListContext, hits, index);
        },
      ),
    );
  }

  Widget _buildRecipeCard(
      BuildContext topLevelContext, List<APIHits> hits, int index) {
    final recipe = hits[index].recipe;
    return GestureDetector(
      onTap: () {
        Navigator.push(topLevelContext, MaterialPageRoute(
          builder: (context) {
            return const RecipeDetails();
          },
        ));
      },
      child: recipeCard(recipe),
    );
  }
}

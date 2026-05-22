import 'package:flutter/material.dart';

import '../../models/expense_category_model.dart';
import '../../services/expense_category_service.dart';

class ExpenseCategoryScreen
    extends StatefulWidget {

  final int businessId;

  const ExpenseCategoryScreen({

    super.key,

    required this.businessId,
  });

  @override
  State<ExpenseCategoryScreen>
      createState() =>
          _ExpenseCategoryScreenState();
}

class _ExpenseCategoryScreenState
    extends State<
        ExpenseCategoryScreen> {

  final ExpenseCategoryService
      expenseCategoryService =
      ExpenseCategoryService();

  final TextEditingController
      categoryController =
      TextEditingController();

  List<ExpenseCategoryModel>
      categories = [];

  @override
  void initState() {

    super.initState();

    loadCategories();
  }

  Future loadCategories() async {

    categories =
        await expenseCategoryService
            .getExpenseCategories(
      widget.businessId,
    );

    setState(() {});
  }

  Future addCategory() async {

    if (categoryController.text
        .trim()
        .isEmpty) {

      return;
    }

    ExpenseCategoryModel
        category =
        ExpenseCategoryModel(

      businessId:
          widget.businessId,

      name:
          categoryController.text
              .trim(),
    );

    await expenseCategoryService
        .createExpenseCategory(
      category,
    );

    categoryController.clear();

    loadCategories();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'Expense Categories',
        ),
      ),

      body: Padding(

        padding:
            const EdgeInsets.all(16),

        child: Column(

          children: [

            TextField(

              controller:
                  categoryController,

              decoration:
                  InputDecoration(

                labelText:
                    'Category Name',

                border:
                    OutlineInputBorder(),

                suffixIcon: IconButton(

                  onPressed:
                      addCategory,

                  icon: const Icon(
                    Icons.add,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Expanded(

              child: ListView.builder(

                itemCount:
                    categories.length,

                itemBuilder:
                    (context, index) {

                  final category =
                      categories[index];

                  return Card(

                    child: ListTile(

                      leading: CircleAvatar(

                        child: Text(
                          '${index + 1}',
                        ),
                      ),

                      title: Text(
                        category.name,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
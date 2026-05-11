import '../db/database_helper.dart';
import '../models/business_model.dart';

class BusinessService {

  // =========================
  // CREATE BUSINESS
  // =========================

  Future<int> createBusiness(
    BusinessModel business,
  ) async {

    return await DatabaseHelper
        .instance
        .insertBusiness(
      business,
    );
  }

  // =========================
  // GET ALL BUSINESSES
  // =========================

  Future<List<BusinessModel>>
      getBusinesses() async {

    return await DatabaseHelper
        .instance
        .getBusinesses();
  }

  // =========================
  // UPDATE BUSINESS
  // =========================

  Future updateBusiness(
    BusinessModel business,
  ) async {

    await DatabaseHelper
        .instance
        .updateBusiness(
      business,
    );
  }

  // =========================
  // DELETE BUSINESS
  // =========================

  Future deleteBusiness(
    int businessId,
  ) async {

    await DatabaseHelper
        .instance
        .deleteBusiness(
      businessId,
    );
  }
}
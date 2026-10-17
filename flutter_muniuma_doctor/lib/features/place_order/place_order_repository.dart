import 'package:flutter_muniuma_doctor/core/network/api_client.dart';

class PlaceOrderRepository {
  PlaceOrderRepository(this.api);

  final ApiClient api;

  Future<List<Map<String, dynamic>>> hospitals() {
    return _list('user/Hospital/GetHospitalList', {
      'DataStatus': 2,
      'PageIndex': 1,
      'PageSize': 100,
    });
  }

  Future<List<Map<String, dynamic>>> factories(String hospitalId) {
    return _list('user/FactoryHospital/GetCooperationFactory', {
      'HospitalId': hospitalId,
      'PageIndex': 1,
      'PageSize': 100,
    });
  }

  Future<List<Map<String, dynamic>>> doctors(String hospitalId, String factoryId) {
    return _list('user/Doctor/GetDoctorList', {
      'HospitalId': hospitalId,
      'FactoryId': factoryId,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<bool> isManageOrAssistant({
    required String hospitalId,
    required String factoryId,
    required String userName,
  }) async {
    final list = await _list('user/Doctor/GetDoctorRoleList', {
      'HospitalId': hospitalId,
      'FactoryId': factoryId,
      'PageIndex': 1,
      'PageSize': 9999,
    });
    for (final item in list) {
      if (field(item, const ['name']) != userName) continue;
      final roles = item['doctorRoles'];
      if (roles is! List) return false;
      for (final role in roles.whereType<Map>()) {
        final name = field(Map<String, dynamic>.from(role), const ['name']);
        if (name == '管理者' || name == '助手') return true;
      }
      return false;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> addresses({
    required String hospitalId,
    required String factoryId,
  }) {
    return _list('user/FactoryHospitalShippingAddr/GetHospitalShippingAddr', {
      'PageIndex': 1,
      'PageSize': 999,
      'hospitalId': hospitalId,
      'FactoryId': factoryId,
      'DataStatus': 2,
    });
  }

  Future<void> addAddress(Map<String, dynamic> body) async {
    await api.post('user/Hospital/AddHospitalShippingAddr', body: body);
  }

  Future<List<Map<String, dynamic>>> productLabels(String factoryHospitalId) {
    return _list('product/ProductHospital/GetProductTypeLabelSelectList', {
      'FactoryHospitalId': factoryHospitalId,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> productTypes({
    required String factoryHospitalId,
    required String factoryId,
    required String typeLabelId,
  }) {
    return _list('product/ProductType/GetProductTypeByPlaceOrder', {
      'factoryHospitalId': factoryHospitalId,
      'factoryId': factoryId,
      'typeLabelId': typeLabelId,
    });
  }

  Future<List<Map<String, dynamic>>> placeOrderProducts({
    required String factoryHospitalId,
    required String factoryId,
    required String typeLabelId,
    required String productTypeId,
    required String doctorId,
    int page = 1,
    String? plantSystemId,
  }) {
    return _list('product/ProductHospital/GetPlaceOrderProductList', {
      'FactoryHospitalId': factoryHospitalId,
      'FactoryId': factoryId,
      'TypeLabelId': typeLabelId,
      'ProductTypeId': productTypeId,
      'DoctorId': doctorId,
      'PageIndex': page,
      'PageSize': 20,
      if (plantSystemId != null && plantSystemId.isNotEmpty)
        'PlantSystemId': plantSystemId,
    });
  }

  Future<List<Map<String, dynamic>>> searchProducts({
    required String factoryHospitalId,
    required String factoryId,
    required String keyword,
    int page = 1,
  }) {
    return _list('product/ProductHospital/GetPlaceOrderProductHospitalList', {
      'FactoryHospitalId': factoryHospitalId,
      'FactoryId': factoryId,
      'CustomName': keyword,
      'PageIndex': page,
      'PageSize': 20,
    });
  }

  Future<List<Map<String, dynamic>>> colorGroups(List<String> productIds) {
    return _list('product/ProductColor/GetGroupColor', {
      'DataStatus': 2,
      'Position': 1,
      'ProductIds': productIds,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> scanBrands() {
    return _list('basic/OralScanBrand/GetSelectList', {
      'DataStatus': 2,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> enumItems(String enumName) {
    return _list('basic/Enum/Get', {'enumName': enumName});
  }

  Future<List<Map<String, dynamic>>> designs({
    required String productIds,
    required String factoryId,
  }) {
    return _list('basic/Design/GetDesignListByProductIds', {
      'ProductIds': productIds,
      'FactoryId': factoryId,
    });
  }

  Future<List<Map<String, dynamic>>> trials(List<String> productIds) {
    return _list('product/ProductHospital/GetProductTrial', {
      'Ids': productIds.join('|'),
    });
  }

  Future<List<Map<String, dynamic>>> enclosures(String factoryId) {
    return _list('basic/Enclosure/GetList', {
      'DataStatus': 2,
      'FactoryId': factoryId,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> phenomenonTypes() {
    return _list('basic/ClinicalPhenomenon/GetClinicalPhenomenonTypeList', {
      'DataStatus': 2,
    });
  }

  Future<List<Map<String, dynamic>>> phenomena(String typeId, int page) {
    return _list('basic/ClinicalPhenomenon/GetClinicalPhenomenonList', {
      'DataStatus': 2,
      'TypeId': typeId,
      'PageIndex': page,
      'PageSize': 20,
    });
  }

  Future<List<Map<String, dynamic>>> plantSystems({
    required String factoryHospitalId,
    required String doctorId,
    String? typeLabelId,
  }) {
    return _list('basic/PlantSystemHospital/GetListByCreateOrder', {
      'FactoryHospitalId': factoryHospitalId,
      'DoctorId': doctorId,
      'PageIndex': 1,
      'PageSize': 9999,
      if (typeLabelId != null && typeLabelId.isNotEmpty) 'TypeLabelId': typeLabelId,
    });
  }

  Future<List<Map<String, dynamic>>> plantImplants(String plantSystemId) {
    return _list('basic/PlantImplant/GetPlantImplantSelectList', {
      'PlantSystemId': plantSystemId,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> plantHoles(String plantSystemId) {
    return _list('basic/PlantHole/GetPlantHoleList', {
      'PlantSystemId': plantSystemId,
      'DataStatus': 2,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> plantRods(String plantSystemId) {
    return _list('basic/PlantRod/GetPlantRodList', {
      'PlantSystemId': plantSystemId,
      'PageIndex': 1,
      'PageSize': 9999,
    });
  }

  Future<List<Map<String, dynamic>>> coupons({
    required String doctorId,
    required String productHospitalId,
  }) {
    return _list('ThirdParty/MeiYuanCoupon/GetCouponList', {
      'doctorId': doctorId,
      'productHospitalId': productHospitalId,
    });
  }

  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> body) async {
    final data = await api.post('order/Order/PlaceOrders', body: body);
    return asMap(data);
  }

  Future<Map<String, dynamic>> orderDetail(String id) {
    return _map('order/Order/GetOrderDetail', {'Id': id});
  }

  Future<List<Map<String, dynamic>>> _list(
    String path,
    Map<String, dynamic> query,
  ) async {
    return asMapList(await api.get(path, query: query));
  }

  Future<Map<String, dynamic>> _map(
    String path,
    Map<String, dynamic> query,
  ) async {
    return asMap(await api.get(path, query: query));
  }
}

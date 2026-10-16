import 'package:flutter_muniuma_doctor/core/network/api_client.dart';
import 'package:flutter_muniuma_doctor/core/session/app_session.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.banners,
    required this.express,
    required this.pending,
    required this.soon,
    required this.favorites,
    required this.inFactory,
    required this.waitCount,
    required this.hasMore,
    required this.aiEnabled,
    this.message,
  });

  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> express;
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> soon;
  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> inFactory;
  final int waitCount;
  final bool hasMore;
  final bool aiEnabled;
  final String? message;
}

class WorkbenchRepository {
  WorkbenchRepository(this.api, this.session);

  final ApiClient api;
  final AppSession session;

  Future<HomeSnapshot> loadHome({int page = 1}) async {
    String? message;
    Future<List<Map<String, dynamic>>> guard(
      Future<dynamic> request,
    ) async {
      try {
        return asMapList(await request);
      } on ApiException catch (error) {
        message ??= error.message;
        return const [];
      }
    }

    final banners = await guard(
      api.get(
        'basic/Advert/GetAdvertList',
        query: {'Citys': '', 'Type': 1},
      ),
    );
    final express = await guard(
      api.get(
        'order/Order/GetOrderExpressBannerList',
        query: {
          'HospitalId': session.hospitalId,
          'PageIndex': 1,
          'PageSize': 20,
        },
      ),
    );
    final pending = await guard(
      api.get(
        'order/Order/GetPendingOrderList',
        query: {'HospitalDoctorId': session.hospitalDoctorId},
      ),
    );
    final soon = await guard(
      api.get(
        'order/Order/GetExpectOutFactoryOrderList',
        query: {'HospitalDoctorId': session.hospitalDoctorId},
      ),
    );
    final favorites = await guard(
      api.get(
        'product/ProductHospital/GetFavoriteProductList',
        query: {'HospitalDoctorId': session.hospitalDoctorId},
      ),
    );
    List<Map<String, dynamic>> inFactory = const [];
    var hasMore = false;
    try {
      final data = await api.get(
        'order/Order/GetOrderList',
        query: {'State': 2, 'PageIndex': page, 'PageSize': 10},
        headers: {'api-version': '2.0'},
      );
      inFactory = asMapList(data);
      hasMore = inFactory.length >= 10;
    } on ApiException catch (error) {
      message ??= error.message;
    }
    var waitCount = 0;
    try {
      waitCount = asCount(
        await api.get('Order/OrderWait/GetUnassociatedCount'),
      );
    } on ApiException catch (error) {
      message ??= error.message;
    }
    var aiEnabled = false;
    try {
      final config = asMap(await api.get('basic/Menu/GetSwitchConfigure'));
      aiEnabled = config['aiSwitch'] == true || config['aiSwitch'] == 'true';
    } catch (_) {}

    try {
      if (session.phone.isNotEmpty) {
        final user = asMap(
          await api.get(
            'user/User/GetUser',
            query: {'phoneNumber': session.phone},
          ),
        );
        if (user.isNotEmpty) {
          final merged = Map<String, dynamic>.from(session.user);
          merged.addAll(user);
          await session.patchUser(merged);
        }
      }
    } catch (_) {}

    return HomeSnapshot(
      banners: banners,
      express: express,
      pending: pending,
      soon: soon,
      favorites: favorites.length > 4 ? favorites.sublist(0, 4) : favorites,
      inFactory: inFactory,
      waitCount: waitCount,
      hasMore: hasMore,
      aiEnabled: aiEnabled,
      message: message,
    );
  }

  Future<List<Map<String, dynamic>>> orders({
    required int page,
    int? state,
    String? patientName,
    String? orderNo,
  }) async {
    return asMapList(
      await api.get(
        'order/Order/GetOrderList',
        query: {
          'PageIndex': page,
          'PageSize': 10,
          'State': ?state,
          if (patientName != null && patientName.isNotEmpty)
            'PatientName': patientName,
          if (orderNo != null && orderNo.isNotEmpty) 'OrderNo': orderNo,
          'HospitalId': session.hospitalId,
        },
        headers: {'api-version': '2.0'},
      ),
    );
  }

  Future<Map<String, dynamic>> orderDetail(String id) async {
    return asMap(
      await api.get('order/Order/GetOrderDetail', query: {'Id': id}),
    );
  }

  Future<List<Map<String, dynamic>>> shipped(int page) {
    return _list(
      'order/Order/GetShippedOrderList',
      {
        'PageIndex': page,
        'PageSize': 10,
        'HospitalId': session.hospitalId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> pending(int page) {
    return _list('order/Order/GetPendingOrderList', {
      'HospitalDoctorId': session.hospitalDoctorId,
      'PageIndex': page,
      'PageSize': 20,
    });
  }

  Future<List<Map<String, dynamic>>> soon() {
    return _list('order/Order/GetExpectOutFactoryOrderList', {
      'HospitalDoctorId': session.hospitalDoctorId,
    });
  }

  Future<List<Map<String, dynamic>>> waitOrders(int page, {bool? ordered}) {
    return _list('order/OrderWait/GetList', {
      'PageIndex': page,
      'PageSize': 10,
      'dataStatus': 2,
      'HospitalId': session.hospitalId,
      'IsOrder': ?ordered,
    });
  }

  Future<List<Map<String, dynamic>>> favorites() {
    return _list('product/ProductHospital/GetFavoriteProductList', {
      'HospitalDoctorId': session.hospitalDoctorId,
    });
  }

  Future<List<Map<String, dynamic>>> laboratories() {
    return _list('product/Laboratory/GetSimpleList', {
      'HospitalId': session.hospitalId,
    });
  }

  Future<List<Map<String, dynamic>>> hospitals() {
    return _list('user/Hospital/GetHospitalList', const {});
  }

  Future<void> switchHospital(String id) async {
    final hospital = asMap(
      await api.get('user/Hospital/GetHospital', query: {'Id': id}),
    );
    if (hospital.isNotEmpty) {
      await session.saveHospital(hospital, notify: false);
    }
    final login = asMap(
      await api.get(
        'Authen/Authorization/SwitchHospital',
        query: {'HospitalId': id},
      ),
    );
    if (login.isNotEmpty) {
      final merged = Map<String, dynamic>.from(session.login);
      if (login['token'] != null) merged['token'] = login['token'];
      if (login['user'] != null) merged['user'] = login['user'];
      await session.saveLogin(merged);
    }
  }

  Future<List<Map<String, dynamic>>> factories() {
    return _list('user/FactoryHospital/GetCooperationFactory', {
      'HospitalId': session.hospitalId,
    });
  }

  Future<List<Map<String, dynamic>>> serviceStaff(String factoryId, int page) {
    return _list('user/Factory/GetFactoryServiceStaff', {
      'FactoryId': factoryId,
      'PageIndex': page,
      'PageSize': 10,
    });
  }

  Future<List<Map<String, dynamic>>> patients(String keyword, int page) {
    return _list('user/Patient/GetPatientList', {
      'PageIndex': page,
      'PageSize': 20,
      'HospitalId': session.hospitalId,
      if (keyword.isNotEmpty) 'PatientName': keyword,
    });
  }

  Future<String> medicalRecordToken() async {
    final data = await api.get(
      'Authen/Authorization/GetMrToken',
      query: {'loginClient': 2},
    );
    if (data is String) return data;
    if (data is Map) {
      return data['token']?.toString() ?? data.values.first.toString();
    }
    return data?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    final identity = session.imIdentity;
    if (identity == null || session.imToken.isEmpty) return const [];
    final data = await api.get(
      'IM/IM/GetUserGroupList',
      query: {'ImIdentity': identity, 'MsgIndex': 0, 'MsgSize': 20},
      useImToken: true,
    );
    final map = asMap(data);
    if (map['groupListModels'] is List) return asMapList(map['groupListModels']);
    return asMapList(data);
  }

  Future<List<Map<String, dynamic>>> _list(
    String path,
    Map<String, dynamic> query,
  ) async {
    return asMapList(await api.get(path, query: query));
  }
}

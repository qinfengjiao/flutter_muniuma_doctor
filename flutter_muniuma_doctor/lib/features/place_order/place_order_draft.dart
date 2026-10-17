import 'package:flutter/foundation.dart';
import 'package:flutter_muniuma_doctor/core/network/api_client.dart';

bool asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == '1';
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

class OrderAudio {
  OrderAudio(this.path, this.seconds);

  final String path;
  final int seconds;
}

class OrderTooth {
  OrderTooth(this.code, {this.productionType = 1});

  final String code;
  int productionType;
}

class OrderProduct {
  OrderProduct({required this.group, required this.detail});

  final Map<String, dynamic> group;
  final Map<String, dynamic> detail;
  final List<OrderTooth> teeth = [];
  final List<Map<String, dynamic>> plants = [];
  final List<Map<String, dynamic>> coupons = [];
  String trialId = '';
  String trialName = '';
  final List<String> designIds = [];
  final List<String> claspImagePaths = [];
  String claspDesignCos = '';

  String get productHospitalId => field(detail, const ['Id', 'id']);
  String get productId => field(detail, const ['productId', 'ProductId']);
  String get name {
    final custom = field(detail, const ['customName', 'fullProductName', 'productName']);
    if (custom.isNotEmpty) return custom;
    return field(group, const ['name', 'customName', 'productName']);
  }

  bool get isPlant => asBool(detail['isPlant']);
  bool get isTrial => asBool(detail['isTrial']);
  bool get isWarranty => asBool(detail['isWarranty']);
  bool get isToothConjoinedSet => asBool(detail['isToothConjoinedSet']);
  bool get isRequiredColor => asBool(detail['isRequiredColor']);

  String get tooth => teeth.map((item) => item.code).join('|');
  int get toothNum => teeth.length;

  bool get hasReworkOrRepair =>
      teeth.any((item) => item.productionType == 2 || item.productionType == 3);

  void syncPlants() {
    if (!isPlant) {
      plants.clear();
      return;
    }
    final next = <Map<String, dynamic>>[];
    for (final item in teeth) {
      Map<String, dynamic>? old;
      for (final plant in plants) {
        if (field(plant, const ['toothSingle']) == item.code) {
          old = plant;
          break;
        }
      }
      next.add(
        old ??
            {
              'toothSingle': item.code,
              'productId': productId,
              'plantSystemId': field(detail, const ['plantSystemId']),
              'plantSystemName': field(detail, const ['plantSystemName']),
              'productSerieId': field(detail, const ['productSerieId']),
              'productSerieName': field(detail, const ['productSerieName']),
              'plantType': asInt(detail['plantType']),
              'secondOperationTime': '',
              'plantImplantId': '',
              'plantImplantName': '',
              'plantHoleId': '',
              'plantHoleName': '',
              'plantHealcapName': '',
              'plantRodId': '',
              'plantRodName': '',
              'isDesignatedSystem': field(detail, const ['plantSystemId']).isNotEmpty,
            },
      );
    }
    plants
      ..clear()
      ..addAll(next);
  }

  List<Map<String, dynamic>> orderProductTooths() {
    final grouped = <int, List<String>>{};
    final order = <int>[];
    for (final item in teeth) {
      grouped.putIfAbsent(item.productionType, () {
        order.add(item.productionType);
        return [];
      }).add(item.code);
    }
    return [
      for (final type in order)
        {'tooth': grouped[type]!.join('|'), 'productionType': type},
    ];
  }
}

class PlaceOrderDraft {
  PlaceOrderDraft({
    required this.hospital,
    required this.factory,
    required this.doctor,
  });

  final Map<String, dynamic> hospital;
  final Map<String, dynamic> factory;
  final Map<String, dynamic> doctor;

  String patientName = '';
  String patientTel = '';
  int patientSex = 0;
  int patientAge = 0;
  String remark = '';
  final List<String> colorimetricPhotos = [];
  final List<String> otherPhotos = [];
  final List<OrderAudio> audios = [];
  String colorimetricCos = '';
  String otherPhotoCos = '';
  String audioCos = '';

  final List<OrderProduct> products = [];
  int connectType = -1;
  final List<List<String>> segments = [];
  int obtainMould = 1;
  bool canChoiceMould = true;
  bool takeAttachments = false;

  Map<String, dynamic>? scanBrand;
  int sendWayId = 0;
  String sendWayName = '';

  final List<Map<String, dynamic>> colors = [];
  final List<Map<String, dynamic>> designs = [];
  final List<Map<String, dynamic>> attachments = [];
  bool printPhysicalCard = false;

  Map<String, dynamic>? reason;
  Map<String, dynamic>? address;

  String get hospitalId => field(hospital, const ['Id', 'id']);
  String get factoryId => field(factory, const ['factoryId', 'FactoryId']);
  String get factoryHospitalId =>
      field(factory, const ['factoryHospitalId', 'FactoryHospitalId']);
  String get doctorId => field(doctor, const ['doctorId', 'DoctorId']);
  String get hospitalDoctorId =>
      field(doctor, const ['hospitalDoctorId', 'HospitalDoctorId']);

  bool get hasSingleConnected => products.any(
        (item) => item.isToothConjoinedSet && item.tooth.isNotEmpty,
      );

  bool get hasRequiredColor =>
      products.any((item) => item.isRequiredColor && item.tooth.isNotEmpty);

  bool get hasPlant => products.any((item) => item.isPlant);
  bool get hasTrial => products.any((item) => item.isTrial);
  bool get hasWarranty => products.any((item) => item.isWarranty);
  bool get hasRework => products.any((item) => item.hasReworkOrRepair);

  void refreshMould() {
    final values = <int>[];
    for (final product in products) {
      final value = asInt(product.detail['obtainMould']);
      if (value == 0 || values.contains(value)) continue;
      values.add(value);
    }
    if (values.length >= 2) {
      canChoiceMould = true;
      obtainMould = 1;
      return;
    }
    if (values.length == 1) {
      canChoiceMould = false;
      obtainMould = values.first;
      return;
    }
    canChoiceMould = true;
    obtainMould = 1;
    if (products.isEmpty) return;
    final doctorMould = asInt(products.first.detail['doctorObtainMould']);
    if (doctorMould == 1 || doctorMould == 2) {
      canChoiceMould = true;
      obtainMould = doctorMould;
    }
  }

  void applyDefaultColor(OrderProduct product) {
    final main = field(product.detail, const ['colorMain']);
    if (main.isEmpty || colors.isNotEmpty) return;
    colors.add({
      'tooth': product.tooth,
      'colorMain': main,
      'colorMainId': field(product.detail, const ['colorMainId']),
    });
  }

  List<String> conjoinedTeeth() {
    final set = <String>{};
    for (final product in products) {
      if (!product.isToothConjoinedSet || product.tooth.isEmpty) continue;
      set.addAll(product.tooth.split('|').where((item) => item.isNotEmpty));
    }
    final list = set.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    return list;
  }

  String toothConjoined() {
    final teeth = conjoinedTeeth();
    if (connectType == 0) return teeth.join(',');
    if (connectType == 1) {
      final up = teeth.where((item) => (int.tryParse(item) ?? 0) <= 28);
      final down = teeth.where((item) => (int.tryParse(item) ?? 0) > 28);
      final upText = up.join('|');
      final downText = down.join('|');
      if (upText.isEmpty) return downText;
      if (downText.isEmpty) return upText;
      return '$upText,$downText';
    }
    if (connectType == 2) {
      return segments.map((item) => item.join('|')).join(',');
    }
    return '';
  }

  String? validate() {
    if (patientName.trim().isEmpty) return '请输入【患者姓名】';
    if (patientTel.isNotEmpty &&
        !RegExp(r'^1[3-9]\d{9}$').hasMatch(patientTel)) {
      return '手机号码格式不正确';
    }
    if (products.isEmpty) return '请选择产品';
    if (hasSingleConnected && connectType == -1) return '请选择连接方式';
    if (hasRequiredColor && !_hasColorValue()) return '颜色未填，请补充完整';
    if (hasRework && reason == null) return '请选择返工原因';
    if (connectType == 2) {
      final all = conjoinedTeeth().toSet();
      final picked = segments.expand((item) => item).toSet();
      if (all.difference(picked).isNotEmpty) return '分段牙位未选取完全';
    }
    if (address == null) return '请选择或添加地址';
    for (final product in products.where((item) => item.isPlant)) {
      for (final plant in product.plants) {
        if (field(plant, const ['plantSystemId']).isEmpty) return '请选择种植信息';
      }
    }
    return null;
  }

  bool _hasColorValue() {
    const keys = [
      'colorMain',
      'colorAbutment',
      'colorCut',
      'colorMid',
      'colorNeck',
      'customize',
    ];
    for (final color in colors) {
      for (final key in keys) {
        if (field(color, [key]).isNotEmpty) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toPayload() {
    final body = <String, dynamic>{
      'phoneBrand': defaultTargetPlatform.name,
      'phoneOSVer': defaultTargetPlatform.name,
      'phoneSWVer': '1.0.0',
      'comeFrom': 1,
      'sendNo': address == null ? '' : field(address!, const ['sendNo']),
      'factoryHospitalId': factoryHospitalId,
      'hospitalDoctorId': hospitalDoctorId,
      'patientName': patientName.trim(),
      'toothConjoined': toothConjoined(),
      'collectEnclosures': obtainMould == 1
          ? asBool(address?['isPickUp'])
          : takeAttachments,
      'orderProducts': products.map(_productPayload).toList(),
    };
    if (remark.trim().isNotEmpty) body['doctorRemark'] = remark.trim();
    if (patientTel.isNotEmpty) body['patientTel'] = patientTel;
    if (patientAge > 0) body['patientAge'] = patientAge;
    if (patientSex != 0) body['patientSex'] = patientSex;
    if (hasWarranty) body['isPrintPhysicalCard'] = printPhysicalCard;
    if (reason != null) {
      body['clinicalPhenomenonId'] = field(reason!, const ['Id', 'id']);
    }
    final colorList = colors
        .map(_colorPayload)
        .where((item) => item.length > 1)
        .toList();
    if (colorList.isNotEmpty) body['orderColors'] = colorList;
    final designText = designs
        .map((item) => field(item, const ['Id', 'id', 'designId']))
        .where((item) => item.isNotEmpty)
        .join('|');
    if (designText.isNotEmpty) body['designs'] = designText;
    final plants = <Map<String, dynamic>>[];
    for (final product in products.where((item) => item.isPlant)) {
      for (final plant in product.plants) {
        final row = <String, dynamic>{
          'productId': field(plant, const ['productId']),
          'toothSingle': field(plant, const ['toothSingle']),
          'plantSystemId': field(plant, const ['plantSystemId']),
          'plantImplantId': field(plant, const ['plantImplantId']),
          'plantHealcapName': field(plant, const ['plantHealcapName']),
          'plantType': asInt(plant['plantType']),
        };
        final holeId = field(plant, const ['plantHoleId']);
        if (holeId.isNotEmpty) row['plantHoleId'] = holeId;
        if (asInt(plant['plantType']) == 1 &&
            field(plant, const ['secondOperationTime']).isNotEmpty) {
          row['secondOperationTime'] = field(plant, const ['secondOperationTime']);
        }
        if (asInt(plant['plantType']) == 2 &&
            field(plant, const ['plantRodId']).isNotEmpty) {
          row['plantRodId'] = field(plant, const ['plantRodId']);
        }
        plants.add(row);
      }
    }
    if (plants.isNotEmpty) body['orderProductPlantSystem'] = plants;
    final enclosures = [
      for (final item in attachments)
        if (asInt(item['number']) > 0)
          {
            'enclosureId': field(item, const ['Id', 'id']),
            'number': asInt(item['number']),
          },
    ];
    if (enclosures.isNotEmpty) body['orderEnclosures'] = enclosures;
    final doctorFiles = <Map<String, dynamic>>[
      if (colorimetricCos.isNotEmpty)
        {'factoryId': factoryId, 'fileCos': colorimetricCos, 'fileType': 2},
      if (otherPhotoCos.isNotEmpty)
        {'factoryId': factoryId, 'fileCos': otherPhotoCos, 'fileType': 4},
      if (audioCos.isNotEmpty)
        {'factoryId': factoryId, 'fileCos': audioCos, 'fileType': 1},
    ];
    if (doctorFiles.isNotEmpty) body['orderDoctorFiles'] = doctorFiles;
    return body;
  }

  Map<String, dynamic> _productPayload(OrderProduct product) {
    final row = <String, dynamic>{
      'productHospitalId': product.productHospitalId,
      'oldOrderProductId': product.productHospitalId,
      'fullProductName': field(
        product.detail,
        const ['fullProductName', 'productName', 'customName'],
      ),
      'tooth': product.tooth,
      'toothNum': product.toothNum,
      'obtainMould': obtainMould > 0 ? obtainMould : 1,
    };
    if (scanBrand != null && obtainMould == 2) {
      final brandId = field(scanBrand!, const ['Id', 'id']);
      if (brandId.isNotEmpty) {
        row['oralScanBrandId'] = brandId;
        row['oralScanSendType'] = sendWayId;
      }
    }
    final designIds = designs
        .where((item) => _designMatches(item, product.productId))
        .map((item) => field(item, const ['Id', 'id', 'designId']))
        .where((item) => item.isNotEmpty)
        .toList();
    if (designIds.isNotEmpty && product.tooth.isNotEmpty) {
      row['orderDesigns'] = [
        {'designs': designIds.join('|'), 'tooth': product.tooth},
      ];
    }
    final tooths = product.orderProductTooths();
    if (tooths.isNotEmpty) row['orderProductTooths'] = tooths;
    if (product.isTrial && product.trialId.isNotEmpty) {
      row['orderTrials'] = [
        {'tooth': product.tooth, 'trialId': product.trialId},
      ];
    }
    final coupons = [
      for (final coupon in product.coupons)
        if (asBool(coupon['selected']))
          {
            'couponName': field(coupon, const ['couponsName', 'couponName']),
            'userCouponId': asInt(coupon['userCouponId']),
            'amount': asInt(coupon['amount']),
          },
    ];
    if (coupons.isNotEmpty) row['orderProductCoupons'] = coupons;
    if (product.claspDesignCos.isNotEmpty) {
      row['claspDesignCos'] = product.claspDesignCos;
    }
    return row;
  }

  Map<String, dynamic> _colorPayload(Map<String, dynamic> color) {
    final row = <String, dynamic>{};
    const keys = [
      'tooth',
      'colorMain',
      'colorMainId',
      'colorNeck',
      'colorNeckId',
      'colorMid',
      'colorMidId',
      'colorCut',
      'colorCutId',
      'colorAbutment',
      'colorAbutmentId',
      'colorGum',
      'colorGumId',
      'customize',
    ];
    for (final key in keys) {
      final value = field(color, [key]);
      if (value.isNotEmpty) row[key] = value;
    }
    return row;
  }

  bool _designMatches(Map<String, dynamic> design, String productId) {
    final raw = field(design, const ['productIds', 'ProductIds']);
    if (raw.isEmpty || productId.isEmpty) return true;
    return raw.split(RegExp(r'[|,]')).contains(productId);
  }
}

const mouldOptions = <int, String>{
  1: '常规取模',
  2: '口内扫描',
  4: '医生灌硅胶',
  8: '工厂灌硅胶',
  16: '藻酸盐',
};

String mouldName(int value) => mouldOptions[value] ?? '取模方式$value';

String productionName(int type) {
  switch (type) {
    case 2:
      return '返工';
    case 3:
      return '返修';
    default:
      return '新做';
  }
}

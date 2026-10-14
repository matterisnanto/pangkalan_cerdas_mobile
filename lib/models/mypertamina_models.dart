class PangkalanProfileModel {
  final String registrationId,
      storeName,
      storeAddress,
      phoneNumber,
      tid,
      midMap,
      agenId,
      agenName;
  final bool isAvailableTransaction;
  const PangkalanProfileModel({
    required this.registrationId,
    required this.storeName,
    required this.storeAddress,
    required this.phoneNumber,
    required this.tid,
    required this.midMap,
    required this.isAvailableTransaction,
    required this.agenId,
    required this.agenName,
  });
  factory PangkalanProfileModel.fromJson(Map<String, dynamic> j) =>
      PangkalanProfileModel(
        registrationId: _s(j['registrationId']),
        storeName: _s(j['storeName']),
        storeAddress: _s(j['storeAddress']),
        phoneNumber: _s(j['phoneNumber']),
        tid: _s(j['tid']),
        midMap: _s(j['midMap']),
        isAvailableTransaction: j['isAvailableTransaction'] == true,
        agenId: _s(j['agenId']),
        agenName: _s(j['agenName']),
      );
  Map<String, dynamic> toJson() => {
    'registrationId': registrationId,
    'storeName': storeName,
    'storeAddress': storeAddress,
    'phoneNumber': phoneNumber,
    'tid': tid,
    'midMap': midMap,
    'isAvailableTransaction': isAvailableTransaction,
    'agenId': agenId,
    'agenName': agenName,
  };
}

class ProductStockModel {
  final String productId, productName;
  final int stockAvailable, stockRedeem, sold;
  final num price, modal;
  const ProductStockModel({
    required this.productId,
    required this.productName,
    required this.stockAvailable,
    required this.stockRedeem,
    required this.sold,
    required this.price,
    required this.modal,
  });
  factory ProductStockModel.fromJson(Map<String, dynamic> j) =>
      ProductStockModel(
        productId: _s(j['productId']),
        productName: _s(j['productName']),
        stockAvailable: _n(j['stockAvailable']),
        stockRedeem: _n(j['stockRedeem']),
        sold: _n(j['sold']),
        price: _num(j['price']),
        modal: _num(j['modal']),
      );
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'stockAvailable': stockAvailable,
    'stockRedeem': stockRedeem,
    'sold': sold,
    'price': price,
    'modal': modal,
  };
}

class CustomerTypeModel {
  final String name;
  final String sourceTypeId;
  const CustomerTypeModel({required this.name, required this.sourceTypeId});
  factory CustomerTypeModel.fromJson(Map<String, dynamic> j) =>
      CustomerTypeModel(
        name: _s(j['name']),
        sourceTypeId: _s(j['sourceTypeId']),
      );
  Map<String, dynamic> toJson() => {'name': name, 'sourceTypeId': sourceTypeId};
}

class CustomerVerificationModel {
  final String nationalityId, familyId, familyIdEncrypted, name, token;
  final List<CustomerTypeModel> customerTypes;
  const CustomerVerificationModel({
    required this.nationalityId,
    required this.familyId,
    required this.familyIdEncrypted,
    required this.name,
    required this.token,
    required this.customerTypes,
  });
  factory CustomerVerificationModel.fromJson(Map<String, dynamic> j) =>
      CustomerVerificationModel(
        nationalityId: _s(j['nationalityId']),
        familyId: _s(j['familyId']),
        familyIdEncrypted: _s(j['familyIdEncrypted']),
        name: _s(j['name']),
        token: _s(j['token']),
        customerTypes: (j['customerTypes'] is List
            ? (j['customerTypes'] as List)
                  .whereType<Map>()
                  .map(
                    (e) => CustomerTypeModel.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
            : const []),
      );
}

class QuotaRemainingModel {
  final num dailyPerSegment,
      dailyAll,
      weeklyPerSegment,
      weeklyAll,
      monthly,
      familyQuota;
  const QuotaRemainingModel({
    required this.dailyPerSegment,
    required this.dailyAll,
    required this.weeklyPerSegment,
    required this.weeklyAll,
    required this.monthly,
    required this.familyQuota,
  });
  factory QuotaRemainingModel.fromJson(Map<String, dynamic> j) =>
      QuotaRemainingModel(
        dailyPerSegment: _num(j['dailyPerSegment']),
        dailyAll: _num(j['dailyAll']),
        weeklyPerSegment: _num(j['weeklyPerSegment']),
        weeklyAll: _num(j['weeklyAll']),
        monthly: _num(j['monthly']),
        familyQuota: _num(j['familyQuota']),
      );
}

class TransactionReceiptModel {
  final String transactionId,
      transactionUniqueKey,
      storeName,
      customerName,
      nik,
      category,
      createdAt,
      status;
  final num totalPrice;
  final int quantity;
  const TransactionReceiptModel({
    required this.transactionId,
    required this.transactionUniqueKey,
    required this.storeName,
    required this.customerName,
    required this.nik,
    required this.category,
    required this.totalPrice,
    required this.quantity,
    required this.createdAt,
    required this.status,
  });
  factory TransactionReceiptModel.fromJson(Map<String, dynamic> j) =>
      TransactionReceiptModel(
        transactionId: _s(j['transactionId']),
        transactionUniqueKey: _s(j['transactionUniqueKey']),
        storeName: _s(j['storeName']),
        customerName: _s(j['customerName']),
        nik: _s(j['NIK'] ?? j['nik'] ?? j['nationalityId']),
        category: _s(j['category']),
        totalPrice: _num(j['totalPrice']),
        quantity: _n(j['quantity']),
        createdAt: _s(j['createdAt']),
        status: _s(j['status']),
      );
  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'transactionUniqueKey': transactionUniqueKey,
    'storeName': storeName,
    'customerName': customerName,
    'NIK': nik,
    'category': category,
    'totalPrice': totalPrice,
    'quantity': quantity,
    'createdAt': createdAt,
    'status': status,
  };
}

String _s(dynamic v) => v?.toString() ?? '';
int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
Map<String, dynamic> unwrapJson(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    for (final key in ['data', 'result', 'content']) {
      if (raw[key] is Map<String, dynamic>) {
        return raw[key] as Map<String, dynamic>;
      }
    }
    return raw;
  }
  return const {};
}

List<dynamic> unwrapList(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    for (final key in ['data', 'result', 'content', 'items']) {
      if (raw[key] is List) return raw[key] as List;
    }
  }
  return raw is List ? raw : const [];
}

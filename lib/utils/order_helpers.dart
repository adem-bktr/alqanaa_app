import '../models/models.dart';

/// الرصيد السابق للزبون (Ancien Solde) قبل فاتورة معيّنة.
///
/// `order.remainingBalance` يخزّن رصيد الزبون **بعد** الفاتورة (رصيده السابق + متبقي الفاتورة)،
/// بينما الوصل يحتاج الرصيد **قبلها**، فنطرح متبقي هذه الفاتورة.
double previousDebtOf(Order order) {
  final rem = order.total - order.paidAmount;
  final orderRemaining = rem > 0 ? rem : 0.0;
  final prev = order.remainingBalance - orderRemaining;
  return prev > 0 ? prev : 0.0;
}
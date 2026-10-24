import '../models/models.dart';

/// الرصيد السابق للزبون (Ancien Solde) قبل فاتورة معيّنة.
///
/// `order.remainingBalance` يخزّن رصيد الزبون **بعد** الفاتورة (رصيده السابق + netChange الفاتورة)،
/// بينما الوصل يحتاج الرصيد **قبلها**، فنطرح المتبقي أو الزيادة المدفوعة لهذه الفاتورة.
double previousDebtOf(Order order) {
  final netChange = order.total - order.paidAmount;
  return order.remainingBalance - netChange;
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support_models.dart';
import 'support_service.dart';

final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService(Supabase.instance.client);
});

final myRequestsProvider =
    FutureProvider.autoDispose<List<SupportRequestSummary>>((ref) {
  return ref.read(supportServiceProvider).listMyRequests();
});

final requestDetailProvider =
    FutureProvider.autoDispose.family<SupportRequestDetail, String>((ref, id) {
  return ref.read(supportServiceProvider).getRequest(id);
});

final myVisitsProvider =
    FutureProvider.autoDispose<List<VisitBooking>>((ref) {
  return ref.read(supportServiceProvider).listMyVisits();
});

final visitDepartmentsProvider =
    FutureProvider.autoDispose<List<VisitDepartment>>((ref) {
  return ref.read(supportServiceProvider).listVisitDepartments();
});

final loanTenureOptionsProvider =
    FutureProvider.autoDispose<List<LoanTenureOption>>((ref) {
  return ref.read(supportServiceProvider).listTenureOptions();
});

final complaintCategoriesProvider =
    FutureProvider.autoDispose<List<ComplaintCategory>>((ref) {
  return ref.read(supportServiceProvider).listComplaintCategories();
});

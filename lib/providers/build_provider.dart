import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/component.dart';
import '../services/amazon_api_service.dart';

// Build state and notifier (existing code)
class BuildState {
  final Map<ComponentType, Component?> selectedComponents;

  const BuildState({this.selectedComponents = const {}});

  double get totalPrice {
    return selectedComponents.values
        .where((c) => c != null)
        .map((c) => c!.price)
        .fold(0.0, (sum, price) => sum + price);
  }

  BuildState copyWith({Map<ComponentType, Component?>? selectedComponents}) {
    return BuildState(
      selectedComponents: selectedComponents ?? this.selectedComponents,
    );
  }
}

class BuildNotifier extends Notifier<BuildState> {
  @override
  BuildState build() {
    return const BuildState();
  }

  void selectComponent(Component component) {
    state = state.copyWith(
      selectedComponents: {
        ...state.selectedComponents,
        component.type: component,
      },
    );
  }

  void removeComponent(ComponentType type) {
    final newComponents = Map<ComponentType, Component?>.from(
      state.selectedComponents,
    );
    newComponents.remove(type);

    state = state.copyWith(selectedComponents: newComponents);
  }

  void clearBuild() {
    state = const BuildState();
  }
}

final buildProvider = NotifierProvider<BuildNotifier, BuildState>(
  BuildNotifier.new,
);

// API Service provider
final amazonApiServiceProvider = Provider((ref) => AmazonApiService());

// Search query state - simple map-based approach
final _searchQueries = <ComponentType, String>{};

String _getSearchQuery(ComponentType type) {
  return _searchQueries[type] ?? AmazonApiService.getDefaultQuery(type);
}

void setSearchQuery(ComponentType type, String query) {
  _searchQueries[type] = query;
}

// Components provider - fetches from API
final componentsProvider = FutureProvider.family
    .autoDispose<List<Component>, ({ComponentType type, String query})>((
      ref,
      args,
    ) async {
      final apiService = ref.watch(amazonApiServiceProvider);
      return apiService.searchProducts(
        query: args.query,
        componentType: args.type,
      );
    });

// Helper to get current query for a type
String getCurrentQuery(ComponentType type) => _getSearchQuery(type);

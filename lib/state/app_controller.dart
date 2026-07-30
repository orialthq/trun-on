import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_catalog.dart';
import '../data/incoming_share_service.dart';
import '../domain/models.dart';

final class AppController extends ChangeNotifier {
  AppController(this._incomingShareService)
    : _products = [...DemoCatalog.products],
      _criteria = DemoCatalog.criteria,
      _comparisonIds = {
        DemoCatalog.products[0].id,
        DemoCatalog.products[1].id,
        DemoCatalog.products[2].id,
      };

  final IncomingShareService _incomingShareService;
  final List<Product> _products;
  final Set<String> _comparisonIds;
  final List<IncomingShare> _incomingQueue = [];

  StreamSubscription<void>? _incomingSubscription;
  UserCriteria _criteria;
  InboxFilter _filter = InboxFilter.all;
  bool _initialized = false;

  List<Product> get products => List.unmodifiable(_products);
  UserCriteria get criteria => _criteria;
  InboxFilter get filter => _filter;
  IncomingShare? get pendingShare =>
      _incomingQueue.isEmpty ? null : _incomingQueue.first;

  List<Product> get comparedProducts => _comparisonIds
      .map(productById)
      .whereType<Product>()
      .toList(growable: false);

  List<Product> get filteredProducts {
    return _products
        .where((product) {
          return switch (_filter) {
            InboxFilter.all => true,
            InboxFilter.needsConfirmation =>
              product.analysisStatus == AnalysisStatus.needsConfirmation,
            InboxFilter.undecided =>
              product.analysisStatus == AnalysisStatus.ready &&
                  product.decision == Decision.undecided,
            InboxFilter.decided => product.decision != Decision.undecided,
          };
        })
        .toList(growable: false);
  }

  int get decidedCount =>
      _products.where((p) => p.decision != Decision.undecided).length;

  int get needsConfirmationCount => _products
      .where((p) => p.analysisStatus == AnalysisStatus.needsConfirmation)
      .length;

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _incomingSubscription = _incomingShareService.pendingChanged.listen((_) {
      unawaited(_drainIncomingShares());
    });
    await _drainIncomingShares();
  }

  Future<void> _drainIncomingShares() async {
    try {
      final shares = await _incomingShareService.drainPending();
      final knownIds = _incomingQueue.map((share) => share.id).toSet();
      _incomingQueue.addAll(
        shares.where((share) => !knownIds.contains(share.id)),
      );
      if (shares.isNotEmpty) {
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint('Incoming share drain failed: $error\n$stackTrace');
    }
  }

  void setFilter(InboxFilter value) {
    if (_filter == value) {
      return;
    }
    _filter = value;
    notifyListeners();
  }

  bool isCompared(String productId) => _comparisonIds.contains(productId);

  bool toggleComparison(String productId) {
    if (_comparisonIds.remove(productId)) {
      notifyListeners();
      return true;
    }
    if (_comparisonIds.length >= 3) {
      return false;
    }
    _comparisonIds.add(productId);
    notifyListeners();
    return true;
  }

  void setDecision(String productId, Decision decision) {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) {
      return;
    }
    _products[index] = _products[index].copyWith(decision: decision);
    notifyListeners();
  }

  void toggleConcern(String concern) {
    final concerns = [..._criteria.concerns];
    if (concerns.remove(concern)) {
      _criteria = _criteria.copyWith(concerns: concerns);
      notifyListeners();
      return;
    }
    if (concerns.length >= 3) {
      return;
    }
    concerns.add(concern);
    _criteria = _criteria.copyWith(concerns: concerns);
    notifyListeners();
  }

  void simulateShare() {
    _incomingQueue.add(
      IncomingShare(
        id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
        receivedAt: DateTime.now(),
        sharedText:
            '요즘 가볍게 쓰기 좋다는 데이라이트 선 플루이드 '
            'https://example.com/reels/daylight',
        discoveredUrl: 'https://example.com/reels/daylight',
        sourcePackage: 'demo',
      ),
    );
    notifyListeners();
  }

  Future<void> confirmPendingShare() async {
    final share = pendingShare;
    if (share == null) {
      return;
    }

    final productIndex = _products.indexWhere(
      (product) => product.id == 'daylight-sun-fluid',
    );
    if (productIndex != -1) {
      final current = _products[productIndex];
      _products[productIndex] = current.copyWith(
        analysisStatus: AnalysisStatus.ready,
        savedSourceCount: current.savedSourceCount + 1,
      );
    }

    _incomingQueue.removeAt(0);
    notifyListeners();
    await _incomingShareService.acknowledge([share.id]);
  }

  Future<void> discardPendingShare() async {
    final share = pendingShare;
    if (share == null) {
      return;
    }
    _incomingQueue.removeAt(0);
    notifyListeners();
    await _incomingShareService.acknowledge([share.id]);
  }

  @override
  void dispose() {
    unawaited(_incomingSubscription?.cancel());
    unawaited(_incomingShareService.dispose());
    super.dispose();
  }
}

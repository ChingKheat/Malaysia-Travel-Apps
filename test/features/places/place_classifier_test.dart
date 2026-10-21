import 'package:flutter_test/flutter_test.dart';
import 'package:smart_travel_planner/features/places/services/place_classifier.dart';

void main() {
  group('PlaceClassifier Unit Tests', () {
    test('Correctly classifies clear INDOOR categories and names', () {
      expect(PlaceClassifier.classify(category: 'Restaurant', name: 'Line Clear Nasi Kandar'), isTrue);
      expect(PlaceClassifier.classify(category: 'Cafe', name: 'ChinaHouse Cafe'), isTrue);
      expect(PlaceClassifier.classify(category: 'Food court', name: 'Red Garden Food Paradise'), isTrue);
      expect(PlaceClassifier.classify(category: 'Museum', name: 'Penang State Museum'), isTrue);
      expect(PlaceClassifier.classify(category: 'Art gallery', name: 'Hin Bus Art Depot'), isTrue);
      expect(PlaceClassifier.classify(category: 'Aquarium', name: 'Aquaria KLCC'), isTrue);
      expect(PlaceClassifier.classify(category: 'Shopping mall', name: 'Gurney Plaza'), isTrue);
      expect(PlaceClassifier.classify(category: 'Tourist attraction', name: 'Menara Kuala Lumpur'), isTrue);
      expect(PlaceClassifier.classify(category: 'Tourist attraction', name: 'Komtar Tower Observatory'), isTrue);
    });

    test('Food establishments on beach streets or parks remain INDOOR', () {
      // Name contains "beach" or "park" but category is dining/cafe
      expect(PlaceClassifier.classify(category: 'Cafe', name: 'Khing Cafe (Beach Street)'), isTrue);
      expect(PlaceClassifier.classify(category: 'Food court', name: 'Chai Leng Park Food Court'), isTrue);
      expect(PlaceClassifier.classify(category: 'Restaurant', name: 'My Humble Bowl @ Bukit Tunku'), isTrue);
    });

    test('Correctly classifies clear OUTDOOR categories and names', () {
      expect(PlaceClassifier.classify(category: 'Beach', name: 'Batu Ferringhi Beach'), isFalse);
      expect(PlaceClassifier.classify(category: 'Botanical garden', name: 'Penang Botanic Gardens'), isFalse);
      expect(PlaceClassifier.classify(category: 'Hiking area', name: 'Penang National Park Trail'), isFalse);
      expect(PlaceClassifier.classify(category: 'Waterfall', name: 'Air Terjun Sungai Ara'), isFalse);
      expect(PlaceClassifier.classify(category: 'Tourist attraction', name: 'Pantai Teluk Bayu'), isFalse);
      expect(PlaceClassifier.classify(category: 'Tourist attraction', name: 'Curtis Crest Treetop Walk'), isFalse);
      expect(PlaceClassifier.classify(category: 'Tourist attraction', name: 'Penang Street Art Mural'), isFalse);
      expect(PlaceClassifier.classify(category: 'Historical landmark', name: 'Clan Jetties of Penang'), isFalse);
      expect(PlaceClassifier.classify(category: 'Historical landmark', name: 'Fort Cornwallis'), isFalse);
    });

    test('Leaves ambiguous or mixed categories as NULL for manual review', () {
      expect(PlaceClassifier.classify(category: 'Place of worship', name: 'Batu Caves'), isNull);
      expect(PlaceClassifier.classify(category: 'Buddhist temple', name: 'Kek Lok Si Temple'), isNull);
      expect(PlaceClassifier.classify(category: 'Hindu temple', name: 'Sri Mahamariamman Temple'), isNull);
      expect(PlaceClassifier.classify(category: 'Church', name: "St. George's Anglican Church"), isNull);
      expect(PlaceClassifier.classify(category: 'Market', name: 'Farlim Wednesday Night Market'), isNull);
      expect(PlaceClassifier.classify(category: 'Historical landmark', name: 'The Cenotaph War Memorial'), isNull);
      expect(PlaceClassifier.classify(category: 'Tourist attraction', name: 'George Town UNESCO Historic Site'), isNull);
    });
  });
}

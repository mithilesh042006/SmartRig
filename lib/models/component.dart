enum ComponentType { cpu, gpu, ram, motherboard, storage, psu, pcCase, cooling }

class Component {
  final String id;
  final String name;
  final String brand;
  final ComponentType type;
  final double price;
  final String? imageUrl;
  final Map<String, dynamic> specs;

  const Component({
    required this.id,
    required this.name,
    required this.brand,
    required this.type,
    required this.price,
    this.imageUrl,
    this.specs = const {},
  });

  String get priceFormatted => '\$${price.toStringAsFixed(2)}';
}

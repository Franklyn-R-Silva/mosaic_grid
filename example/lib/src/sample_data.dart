import 'package:flutter/material.dart';

/// A product in the catalog demo.
@immutable
class Product {
  /// Creates a product.
  const Product({
    required this.index,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.stock,
    required this.tags,
    required this.icon,
    required this.hue,
    required this.featured,
  });

  /// Builds a deterministic sample product for [index].
  factory Product.sample(int index) {
    final kind = _kinds[index % _kinds.length];
    final featured = index % 9 == 4;
    return Product(
      index: index,
      name: '${_adjectives[(index * 7) % _adjectives.length]} ${kind.name}',
      category: kind.category,
      description: _descriptions[(index * 5) % _descriptions.length],
      price: 19.9 + (index * 37 % 480) + (index % 3) * 0.5,
      stock: (index * 13) % 7 == 0 ? 0 : (index * 29) % 140,
      tags: [
        for (var t = 0; t < _tags.length; t++)
          if ((index + t * 3) % (t + 4) == 0) _tags[t],
      ],
      icon: kind.icon,
      hue: (index * 47.0) % 360,
      featured: featured,
    );
  }

  /// Position in the catalog, starting at 0.
  final int index;

  /// Display name.
  final String name;

  /// Category label.
  final String category;

  /// Marketing copy, of varying length.
  final String description;

  /// Unit price.
  final double price;

  /// Units in stock; 0 means sold out.
  final int stock;

  /// Short badges shown on the card.
  final List<String> tags;

  /// Illustration shown in place of a photo.
  final IconData icon;

  /// Hue of the illustration background, in degrees.
  final double hue;

  /// Whether the product is promoted to a two-column card.
  final bool featured;

  /// The catalog code, as printed on the card.
  String get code => '#${(index + 1).toString().padLeft(4, '0')}';
}

/// A note in the board demo.
@immutable
class Note {
  /// Creates a note.
  const Note({
    required this.index,
    required this.title,
    required this.body,
    required this.author,
    required this.hue,
    required this.imageAspectRatio,
    required this.icon,
    required this.pinned,
  });

  /// Builds a deterministic sample note for [index].
  factory Note.sample(int index) {
    final hasImage = index % 3 != 1;
    return Note(
      index: index,
      title: _noteTitles[(index * 3) % _noteTitles.length],
      body: _descriptions[(index * 11) % _descriptions.length],
      author: _authors[index % _authors.length],
      hue: (index * 61.0 + 20) % 360,
      imageAspectRatio: hasImage
          ? const [1.6, 1.0, 0.75, 1.3][index % 4]
          : null,
      icon: _kinds[(index * 5) % _kinds.length].icon,
      pinned: index == 0,
    );
  }

  /// Position on the board, starting at 0.
  final int index;

  /// Headline.
  final String title;

  /// Text of the note, of varying length.
  final String body;

  /// Who wrote it.
  final String author;

  /// Hue of the cover, in degrees.
  final double hue;

  /// Aspect ratio of the cover, or null when the note has none.
  final double? imageAspectRatio;

  /// Illustration shown on the cover.
  final IconData icon;

  /// Whether the note is pinned across the whole width of the board.
  final bool pinned;
}

/// A soft two-tone gradient for illustrations, derived from [hue].
LinearGradient illustrationGradient(double hue) {
  final start = HSLColor.fromAHSL(1, hue, 0.62, 0.62).toColor();
  final end = HSLColor.fromAHSL(1, (hue + 38) % 360, 0.70, 0.46).toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [start, end],
  );
}

class _Kind {
  const _Kind(this.name, this.category, this.icon);

  final String name;
  final String category;
  final IconData icon;
}

const _kinds = [
  _Kind('Headphones', 'Audio', Icons.headphones_rounded),
  _Kind('Armchair', 'Home', Icons.chair_rounded),
  _Kind('Camera', 'Photo', Icons.photo_camera_rounded),
  _Kind('Backpack', 'Travel', Icons.backpack_rounded),
  _Kind('Desk Lamp', 'Home', Icons.light_rounded),
  _Kind('Watch', 'Wearables', Icons.watch_rounded),
  _Kind('Speaker', 'Audio', Icons.speaker_rounded),
  _Kind('Plant Pot', 'Garden', Icons.local_florist_rounded),
  _Kind('Keyboard', 'Office', Icons.keyboard_rounded),
  _Kind('Sneakers', 'Sport', Icons.directions_run_rounded),
  _Kind('Coffee Maker', 'Kitchen', Icons.coffee_maker_rounded),
  _Kind('Bicycle', 'Sport', Icons.pedal_bike_rounded),
];

const _adjectives = [
  'Aurora',
  'Nimbus',
  'Terra',
  'Solace',
  'Vertex',
  'Lumen',
  'Harbor',
  'Cobalt',
  'Willow',
  'Summit',
  'Ember',
  'Atlas',
];

const _descriptions = [
  'Compact and light.',
  'Built to last, with a two-year warranty and free returns.',
  'A customer favourite. Recycled materials, carbon-neutral shipping and a '
      'repair programme that keeps it going for years.',
  'Limited edition.',
  'Designed in-house and tested for a thousand hours before it reached the '
      'shelf.',
  'Ships in 24 hours.',
  'Pairs with everything else in the collection. Soft-touch finish, '
      'reinforced seams and a lifetime of spare parts.',
  'New this season.',
];

const _tags = ['New', 'Low stock', 'Eco', 'Bundle', 'Pre-order'];

const _noteTitles = [
  'Moodboard',
  'Weekend trip',
  'Reading list',
  'Kitchen ideas',
  'Studio setup',
  'Garden plan',
  'Quarterly goals',
  'Colour study',
  'Recipe',
  'Field notes',
];

const _authors = ['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Felipe'];

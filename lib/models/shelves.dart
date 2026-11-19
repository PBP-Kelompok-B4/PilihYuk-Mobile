class Shelf {
  final int id;
  final String name;
  final String storeContext;
  final String description;
  final String owner;
  final int itemCount;
  final int saveCount;

  Shelf.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        storeContext = json['store_context'],
        description = json['description'],
        owner = json['owner'],
        itemCount = json['item_count'],
        saveCount = json['save_count'];
}

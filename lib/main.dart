import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo que representa un Libro.
class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String thumbnailUrl;
  final String publishedDate;
  final double rating;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.thumbnailUrl,
    required this.publishedDate,
    required this.rating,
  });

  factory Book.fromJsonApi(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] ?? {};
    
   ///Manejo seguro de autores para evitar crash si la lista está vacía///
    String parsedAuthor = 'Desconocido';
    if (volumeInfo['authors'] != null && (volumeInfo['authors'] as List).isNotEmpty) {
      parsedAuthor = (volumeInfo['authors'] as List).first.toString();
    }
    String image = volumeInfo['imageLinks']?['thumbnail'] ?? '';
    if (image.startsWith('http://')) {
      image = image.replaceFirst('http://', 'https://');
    }

    return Book(
      id: json['id'] ?? '',
      title: volumeInfo['title'] ?? 'Sin título',
      author: parsedAuthor,
      description: volumeInfo['description'] ?? 'Sin descripción disponible.',
      thumbnailUrl: image,
      publishedDate: volumeInfo['publishedDate'] ?? 'Fecha desconocida',
      rating: (volumeInfo['averageRating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'publishedDate': publishedDate,
      'rating': rating,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      description: map['description'],
      thumbnailUrl: map['thumbnailUrl'],
      publishedDate: map['publishedDate'],
      rating: map['rating'],
    );
  }
}

/// Servicio encargado de la comunicación HTTP.
class BookService {
  final String _authority = 'www.googleapis.com';
  final String _path = '/books/v1/volumes';

  Future<List<Book>> searchBooks(String query) async {
    if (query.isEmpty) return [];

    try {
      final uri = Uri.https(_authority, _path, {'q': query});
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null) {
          final List<dynamic> items = data['items'];
          return items.map((json) => Book.fromJsonApi(json)).toList();
        }
        return [];
      } else {
        throw Exception('Error al conectar con la API: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de red: $e');
    }
  }
}

// ==========================================
// LÓGICA DE NEGOCIO
// ==========================================

class BookProvider extends ChangeNotifier {
  final BookService _bookService = BookService();

  List<Book> _searchResults = [];
  bool _isLoading = false;
  String _error = '';
  List<Book> _favorites = [];

  List<Book> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get error => _error;
  List<Book> get favorites => _favorites;

  BookProvider() {
    _loadFavorites();
  }

  Future<void> searchBooks(String query) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _searchResults = await _bookService.searchBooks(query);
    } catch (e) {
      _error = 'Ocurrió un error: $e';
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleFavorite(Book book) {
    final isFav = _favorites.any((element) => element.id == book.id);

    if (isFav) {
      _favorites.removeWhere((element) => element.id == book.id);
    } else {
      _favorites.add(book);
    }

    _saveFavorites();
    notifyListeners();
  }

  bool isFavorite(String id) {
    return _favorites.any((element) => element.id == id);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      _favorites.map((book) => book.toMap()).toList(),
    );
    await prefs.setString('favorites_books', encodedData);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('favorites_books');

    if (encodedData != null) {
      final List<dynamic> decodedList = json.decode(encodedData);
      _favorites = decodedList.map((item) => Book.fromMap(item)).toList();
      notifyListeners();
    }
  }
}

// ==========================================
// CAPA DE UI
// ==========================================

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BookProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Favoritos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BookProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscador de Libros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar libro...',
                hintText: 'Ej: Harry Potter',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  provider.searchBooks(value);
                }
              },
            ),
          ),
          Expanded(
            child: _buildBody(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BookProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error.isNotEmpty) {
      return Center(child: Text(provider.error, textAlign: TextAlign.center));
    }

    if (provider.searchResults.isEmpty) {
      return const Center(child: Text('Escribe algo para buscar.'));
    }

    return ListView.builder(
      itemCount: provider.searchResults.length,
      itemBuilder: (context, index) {
        final book = provider.searchResults[index];
        return BookListTile(book: book);
      },
    );
  }
}

class BookListTile extends StatelessWidget {
  final Book book;

  const BookListTile({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: book.thumbnailUrl.isNotEmpty
          ? Image.network(
              book.thumbnailUrl,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image),
            )
          : const Icon(Icons.book, size: 50),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(book.author),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(book: book),
          ),
        );
      },
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Book book;

  const DetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookProvider>(
      builder: (context, provider, child) {
        final isFav = provider.isFavorite(book.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(book.title),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              provider.toggleFavorite(book);
            },
            backgroundColor: isFav ? Colors.amber : Colors.grey[200],
            child: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.black : Colors.grey,
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: book.thumbnailUrl.isNotEmpty
                      ? Image.network(book.thumbnailUrl, height: 200)
                      : const Icon(Icons.book, size: 100),
                ),
                const SizedBox(height: 20),
                Text(
                  book.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Por ${book.author}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 5),
                    Text(book.publishedDate),
                    const SizedBox(width: 20),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 5),
                    Text(book.rating > 0 ? book.rating.toString() : 'N/A'),
                  ],
                ),
                const Divider(height: 30),
                const Text(
                  "Sinopsis",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(book.description),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BookProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Favoritos'),
      ),
      body: provider.favorites.isEmpty
          ? const Center(child: Text('Aún no tienes favoritos.'))
          : ListView.builder(
              itemCount: provider.favorites.length,
              itemBuilder: (context, index) {
                final book = provider.favorites[index];
                return BookListTile(book: book);
              },
            ),
    );
  }
}


import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'village_market.db');
    return await openDatabase(
      path, 
      version: 6, 
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        role TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        avatar TEXT
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        image TEXT,
        farmer_id INTEGER,
        created_at TEXT,
        FOREIGN KEY (farmer_id) REFERENCES users (id)
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        buyer_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        total_price REAL,
        status TEXT,
        shipping_address TEXT,
        contact_number TEXT,
        buyer_name TEXT,
        created_at TEXT,
        FOREIGN KEY (buyer_id) REFERENCES users (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Cart table
    await db.execute('''
      CREATE TABLE cart (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        buyer_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        FOREIGN KEY (buyer_id) REFERENCES users (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Wishlist table
    await db.execute('''
      CREATE TABLE wishlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        buyer_id INTEGER,
        product_id INTEGER,
        FOREIGN KEY (buyer_id) REFERENCES users (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
    
    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        message TEXT NOT NULL,
        sender_id INTEGER,
        receiver_id INTEGER,
        created_at TEXT,
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (sender_id) REFERENCES users (id),
        FOREIGN KEY (receiver_id) REFERENCES users (id)
      )
    ''');
    
    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT NOT NULL,
        user_id INTEGER,
        is_read INTEGER DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // COVI Images table (shared gallery)
    await db.execute('''
      CREATE TABLE covi_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        caption TEXT,
        story TEXT,
        uploader_id INTEGER,
        uploader_role TEXT,
        created_at TEXT,
        FOREIGN KEY (uploader_id) REFERENCES users (id)
      )
    ''');

    // COVI Likes table
    await db.execute('''
      CREATE TABLE covi_likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        covi_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        created_at TEXT,
        UNIQUE(covi_id, user_id),
        FOREIGN KEY (covi_id) REFERENCES covi_images (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Add new columns to orders table for version 2
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN shipping_address TEXT;');
        print('Added shipping_address column to orders table');
        
        await db.execute('ALTER TABLE orders ADD COLUMN contact_number TEXT;');
        print('Added contact_number column to orders table');
        
        await db.execute('ALTER TABLE orders ADD COLUMN buyer_name TEXT;');
        print('Added buyer_name column to orders table');
      } catch (e) {
        print('Error upgrading database: $e');
      }
    }
    
    if (oldVersion < 3) {
      // Add notifications table for version 3
      try {
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            type TEXT NOT NULL,
            user_id INTEGER,
            is_read INTEGER DEFAULT 0,
            created_at TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        print('Added notifications table');
      } catch (e) {
        print('Error adding notifications table: $e');
      }
    }

    if (oldVersion < 4) {
      // Add covi_images table for version 4
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS covi_images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            caption TEXT,
            story TEXT,
            uploader_id INTEGER,
            uploader_role TEXT,
            created_at TEXT,
            FOREIGN KEY (uploader_id) REFERENCES users (id)
          )
        ''');
        print('Added covi_images table');
      } catch (e) {
        print('Error adding covi_images table: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        // Add avatar column to users if missing
        await db.execute('ALTER TABLE users ADD COLUMN avatar TEXT;');
      } catch (e) {
        print('Avatar column may already exist: $e');
      }
      try {
        // Ensure story column exists in covi_images
        await db.execute('ALTER TABLE covi_images ADD COLUMN story TEXT;');
      } catch (e) {
        print('Story column may already exist: $e');
      }
      try {
        // Add likes table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS covi_likes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            covi_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            created_at TEXT,
            UNIQUE(covi_id, user_id),
            FOREIGN KEY (covi_id) REFERENCES covi_images (id),
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
      } catch (e) {
        print('Error creating covi_likes table: $e');
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN address TEXT;');
        print('Added address column to users table');
      } catch (e) {
        print('Address column may already exist (v6): $e');
      }
    }
  }
}

import { DatabaseSync } from "node:sqlite";
import { existsSync, unlinkSync } from "node:fs";
import { resolve } from "node:path";

const dbPath = resolve(process.cwd(), "sample.db");

if (existsSync(dbPath)) {
  unlinkSync(dbPath);
}

const db = new DatabaseSync(dbPath);

db.exec(`
  CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT,
    age INTEGER,
    salary REAL
  );
`);

const insertUser = db.prepare(
  "INSERT INTO users (id, name, email, age, salary) VALUES (?, ?, ?, ?, ?)"
);

insertUser.run(1, "Alice Smith", "alice@example.com", 30, 85000.50);
insertUser.run(2, "Bob Jones", "bob@example.com", 25, 62000.00);
insertUser.run(3, "Charlie Brown", "charlie@example.com", 35, 95500.75);
insertUser.run(4, "Diana Prince", "diana@example.com", 28, 78200.25);
insertUser.run(5, "Evan Wright", "evan@example.com", 42, 110000.00);

db.exec(`
  CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT,
    category TEXT,
    price REAL,
    in_stock INTEGER
  );
`);

const insertProduct = db.prepare(
  "INSERT INTO products (product_id, product_name, category, price, in_stock) VALUES (?, ?, ?, ?, ?)"
);

insertProduct.run(101, "Laptop Pro 16", "Electronics", 1899.99, 12);
insertProduct.run(102, "Mechanical Keyboard", "Accessories", 129.50, 45);
insertProduct.run(103, "Wireless Ergonomic Mouse", "Accessories", 49.99, 120);
insertProduct.run(104, "4K Ultra-Wide Monitor", "Electronics", 649.00, 8);
insertProduct.run(105, "USB-C Multi-Port Hub", "Cables & Hubs", 39.90, 85);

db.close();

console.log(`[SUCCESS] Sample SQLite database created at: ${dbPath}`);

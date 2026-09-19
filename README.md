# sqlite-abap

> A pure ABAP implementation for reading, parsing, and iterating SQLite 3 database files directly—without native C bindings, external drivers, or ODBC connections.

[![abaplint](https://img.shields.io/badge/abaplint-clean-brightgreen.svg)](https://abaplint.org)
[![abapGit](https://img.shields.io/badge/abapGit-ready-blue.svg)](https://abapgit.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📖 Overview

**sqlite-abap** allows SAP ABAP applications to read SQLite 3 database files (`.db`, `.sqlite`) natively. It parses the binary SQLite database format directly in ABAP memory, decoding B-tree pages, table schemas, varints, records, and typed column values.

The project is built to run both:
- **On SAP NetWeaver / ABAP Platform**: Installable via [abapGit](https://docs.abapgit.org/).
- **Locally on Node.js**: Transpiled and executed with [@abaplint/transpiler](https://github.com/abaplint/transpiler).

---

## ✅ Requirements

| Requirement | Version |
|---|---|
| Node.js | `>=20.0.0` (transpile + demo `node:sqlite`) |
| ABAP | `v702` (SAP_BASIS 702, downport compatible, installable via abapGit) |
| abapGit | Latest version (on-premise / Steampunk) |
| abaplint | `>=2.120` (verified via `npm run lint`) |

---

## ⚡ Features

- **SQLite Header Parsing**: Decodes the 100-byte file header (magic string verification, page size, usable page size, text encoding, user version, change counter).
- **Varint (Variable-Length Integer) Engine**: Full support for SQLite 1-to-9 byte varint format.
- **B-Tree Navigation**:
  - Traverses Interior Table Pages (`0x05`) and Leaf Table Pages (`0x0D`).
  - Stack-based depth-first search iterator (`zcl_sqlite_iterator`).
  - Automatic resolution and reassembly of chained overflow pages.
- **SQLite Master Schema Parser**:
  - Reads `sqlite_schema` (`sqlite_master`) on Page 1.
  - Extracts table names, root pages, SQL statements, column definitions, and detects `WITHOUT ROWID` tables and primary key RowID aliases.
- **Record Decoder & Typed Values**:
  - Decodes SQLite Record Format header and serial types:
    - Serial Type `0`: `NULL`
    - Serial Types `1-4`: 1, 2, 3, and 4-byte two's complement integers
    - Serial Type `5`: 6-byte big-endian integer
    - Serial Type `6`: 8-byte big-endian integer
    - Serial Types `8-9`: Integer constants `0` and `1`
    - Serial Types `≥ 12` (even): BLOB values
    - Serial Types `≥ 13` (odd): UTF-8 text strings
- **Platform-Agnostic File Reading**:
  - Local/Node runtime: Reads files via Node `fs` kernel hooks.
  - SAP GUI / App Server runtime: Supports frontend upload or application server datasets.

---

## 🚀 Quick Start

### 1. Installation

Clone the repository and install dev dependencies:

```bash
git clone https://github.com/furkancosgun/sqlite-abap.git
cd sqlite-abap
npm install
```

### 2. Run the Demo

Run the end-to-end demonstration program (`zsqlite_demo`). This script generates a sample SQLite database (`sample.db`), transpiles the ABAP sources, and scans all tables and records:

```bash
npm run demo
```

**Sample Output:**
```text
==================================================================
       Pure ABAP SQLite Reader - Demonstration                    
==================================================================
[+] Database Opened Successfully
   * Page Size: 4096 bytes
   * Usable Page Size: 4096 bytes
   * Total Page Count: 3
   * SQLite Version: 3053004
[+] Discovered Tables (sqlite_schema / Master Table - Page 1):
   -> Table: users | RootPage: 2 | Columns: [id, name, email, age, salary]
========================================================
[*] SCANNING TABLE: users (RootPage: 2)
    withoutRowId = 
========================================================
-> RowID: 1
   id [INTEGER] = 1
   name [TEXT] = Alice Smith
   email [TEXT] = alice@example.com
   age [INTEGER] = 30
   salary [REAL] = 85000.5000000000000000
-> RowID: 2
   id [INTEGER] = 2
   name [TEXT] = Bob Jones
   email [TEXT] = bob@example.com
   age [INTEGER] = 25
   salary [INTEGER] = 62000
...
[OK] SQLite database scanned successfully with Pure ABAP B-Tree & Record Parser!
```

### 3. Run Tests & Linter

```bash
# Run abaplint and ABAP Unit tests
npm test

# Run abaplint only
npm run lint

# Auto-fix linting issues
npm run fix
```

---

## 💻 ABAP Usage Example

```abap
DATA lo_reader TYPE REF TO zcl_sqlite_reader.
DATA lo_it     TYPE REF TO zcl_sqlite_iterator.
DATA lo_row    TYPE REF TO zcl_sqlite_row.
DATA ls_val    TYPE zcl_sqlite_types=>ty_s_value.

TRY.
    " 1. Open the SQLite database file
    CREATE OBJECT lo_reader
      EXPORTING
        iv_path = 'sample.db'.

    " 2. Retrieve table metadata from sqlite_schema
    DATA(lt_tables) = lo_reader->get_tables( ).

    " 3. Open a streaming iterator for a specific table
    lo_it = lo_reader->open_iterator( 'users' ).

    " 4. Iterate over rows
    WHILE lo_it->has_next( ) = abap_true.
      lo_row = lo_it->next( ).

      " Access by column name
      ls_val = lo_row->get_value_by_name( 'name' ).
      WRITE: / |RowID { lo_row->mv_rowid }: { ls_val-text_value }|.

      " Or format full row as string
      WRITE: / lo_row->to_string( ).
    ENDWHILE.

  CATCH zcx_sqlite_error INTO DATA(lx_error).
    WRITE: / |Error: { lx_error->get_text( ) }|.
ENDTRY.
```

---

## 🏛️ Architecture & Components

```
src/
├── zcl_sqlite_reader.clas.abap          # Facade: file I/O, header, page-cache, sqlite_schema
├── zcl_sqlite_iterator.clas.abap        # B-Tree traverser (stack DFS, leaf/interior dispatch)
├── zcl_sqlite_btree_page.clas.abap      # Value object: B-Tree page parse (0x0D/0x05, cell offsets)
├── zcl_sqlite_overflow_handler.clas.abap # Overflow reassembly (calc_local_size + chain)
├── zcl_sqlite_record_decoder.clas.abap  # Record & serial-type decoder (0-11, BLOB/TEXT, RowID alias)
├── zcl_sqlite_row.clas.abap             # Row container (get_value_by_name/index, to_string)
├── zcl_sqlite_schema_parser.clas.abap   # DDL parser (column names, WITHOUT ROWID, RowID alias)
├── zcl_sqlite_codec.clas.abap           # Big-endian codec (int8/16/24/32/48/64, double) - DRY via read_be_unsigned
├── zcl_sqlite_varint.clas.abap          # SQLite varint (1-9 bytes)
├── zcl_sqlite_types.clas.abap           # Shared types (ty_s_value/ty_s_column/ty_s_schema) + factories
├── zcx_sqlite_error.clas.abap           # Exception (raise/raise_syst)
└── zsqlite_demo.prog.abap               # Demo report
```

### Component Details

| Object | Type | Description |
|---|---|---|
| `zcl_sqlite_reader` | Class | DB lifecycle, `read_file` (Node `fs` / `GUI_UPLOAD`), `parse_header`, `mt_cache`, `load_schemas`, `open_iterator`. |
| `zcl_sqlite_iterator` | Class | Stack-DFS, `push_frame` via `zcl_sqlite_btree_page`, overflow via `zcl_sqlite_overflow_handler`, row via `zcl_sqlite_record_decoder`. |
| `zcl_sqlite_btree_page` | Class | Stateless parser: `parse`, `is_leaf/is_interior`, `read_cell_offsets`, header 100/0. |
| `zcl_sqlite_overflow_handler` | Class | SQLite payload spec (`max=usable-35`, `min=(usable-12)*32/255-23`), `reassemble` + overflow chain. |
| `zcl_sqlite_record_decoder` | Class | Record header varints, `build_row_*`, `decode_value` (serial 0-11, BLOB/TEXT). |
| `zcl_sqlite_row` | Class | `mv_rowid`, `mt_columns`, `get_value_by_name/index`, `to_string`. |
| `zcl_sqlite_schema_parser` | Class | `extract_column_names`, `split_columns`, `get_rowid_alias_index`, `is_without_rowid` (DRY helpers). |
| `zcl_sqlite_codec` | Class | `read_uint8/int8/16/24/32/48/64/double/text/bytes` + private `read_be_unsigned/apply_sign_*`. |
| `zcl_sqlite_varint` | Class | SQLite 1-9 byte varint (`7F/80` mask). |
| `zcl_sqlite_types` | Class | `c_type` (NULL/INTEGER/REAL/TEXT/BLOB), `value_*` factories, `value_to_string`. |
| `zcx_sqlite_error` | Class | `raise`, `raise_syst`, `get_text`. |
| `zsqlite_demo` | Program | `lcl_demo=>run/print_table_preview` — scans two tables (users/products). |

---

## ⚠️ Limitations & Not Supported

- **Read-only:** `SELECT` / iteration only; `INSERT/UPDATE/DELETE`, WAL, `VACUUM`, and encrypted DBs are not supported.
- **B-Tree:** only table B-Trees `0x0D` (leaf table) and `0x05` (interior table) — index B-Trees `0x0A/0x02` traversal is not implemented, `WITHOUT ROWID` tables are partially supported.
- **Types:** Serial Type `10/11` (reserved) → `NULL`; IEEE754 `read_double` for `REAL` may show deviation on edge values (e.g. `1899.99`) — known pre-existing float bug.
- **File:** single DB file, no `ATTACH` / `temp` DB; page-size `1 (=65536)` handling is included.

---

## 📦 SAP Deployment (abapGit)

1. Ensure [abapGit](https://github.com/abapGit/abapGit) is installed in your SAP system.
2. In abapGit, create a new offline repository or clone this repository URL.
3. Pull the repository into a target package (e.g. `$SQLITE` or `ZSQLITE`).
4. Activate all objects.
5. Execute program `ZSQLITE_DEMO` via transaction `SE38` or `SA38`.

---

## 🛠️ Development Scripts

| Command | Description |
|---|---|
| `npm run demo` | Generates `sample.db`, transpiles, and runs `zsqlite_demo`. |
| `npm run create-db` | Generates a sample SQLite database (`sample.db`). |
| `npm run build` | Transpiles ABAP sources into JavaScript (`output/`). |
| `npm test` | Runs linter (`abaplint`) followed by unit tests. |
| `npm run lint` | Runs `abaplint` static analysis across all files. |
| `npm run fix` | Automatically applies fixable `abaplint` rules. |
| `npm run clean` | Cleans the transpiler output directory. |

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'
import { fileURLToPath } from 'node:url'
import { DatabaseSync } from 'node:sqlite'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const zipPath = process.argv[2] || path.resolve(root, '..', '..', 'Desktop', 'theReader.zip')
const resourcesDir = path.resolve(root, 'App', 'Resources')
const dbPath = path.resolve(resourcesDir, 'Books.sqlite')

const zipBytes = fs.readFileSync(zipPath)
const utf8 = new TextDecoder('utf-8')
const gb18030 = new TextDecoder('gb18030')

function findEndOfCentralDirectory(buffer) {
  const min = Math.max(0, buffer.length - 0xffff - 22)
  for (let i = buffer.length - 22; i >= min; i -= 1) {
    if (buffer.readUInt32LE(i) === 0x06054b50) {
      return i
    }
  }
  throw new Error('ZIP end of central directory not found')
}

function decodeName(rawName, flags) {
  if ((flags & 0x800) !== 0) {
    return utf8.decode(rawName)
  }

  const gb = gb18030.decode(rawName)
  if (!gb.includes('\uFFFD')) {
    return gb
  }
  return utf8.decode(rawName)
}

function textFromData(data) {
  const text = utf8.decode(data)
  if (!text.includes('\uFFFD')) {
    return text
  }
  return gb18030.decode(data)
}

function readEntryData(entry) {
  const localOffset = entry.localHeaderOffset
  if (zipBytes.readUInt32LE(localOffset) !== 0x04034b50) {
    throw new Error(`Bad local header for ${entry.path}`)
  }

  const localNameLength = zipBytes.readUInt16LE(localOffset + 26)
  const localExtraLength = zipBytes.readUInt16LE(localOffset + 28)
  const dataOffset = localOffset + 30 + localNameLength + localExtraLength
  const compressed = zipBytes.subarray(dataOffset, dataOffset + entry.compressedSize)

  if (entry.method === 0) {
    return compressed
  }
  if (entry.method === 8) {
    return zlib.inflateRawSync(compressed)
  }
  throw new Error(`Unsupported compression method ${entry.method} for ${entry.path}`)
}

function readCentralDirectory() {
  const eocd = findEndOfCentralDirectory(zipBytes)
  const entryCount = zipBytes.readUInt16LE(eocd + 10)
  let offset = zipBytes.readUInt32LE(eocd + 16)
  const entries = []

  for (let i = 0; i < entryCount; i += 1) {
    if (zipBytes.readUInt32LE(offset) !== 0x02014b50) {
      throw new Error(`Bad central directory header at ${offset}`)
    }

    const flags = zipBytes.readUInt16LE(offset + 8)
    const method = zipBytes.readUInt16LE(offset + 10)
    const compressedSize = zipBytes.readUInt32LE(offset + 20)
    const uncompressedSize = zipBytes.readUInt32LE(offset + 24)
    const nameLength = zipBytes.readUInt16LE(offset + 28)
    const extraLength = zipBytes.readUInt16LE(offset + 30)
    const commentLength = zipBytes.readUInt16LE(offset + 32)
    const localHeaderOffset = zipBytes.readUInt32LE(offset + 42)
    const rawName = zipBytes.subarray(offset + 46, offset + 46 + nameLength)
    const entryPath = decodeName(rawName, flags)

    entries.push({
      path: entryPath,
      method,
      compressedSize,
      uncompressedSize,
      localHeaderOffset
    })

    offset += 46 + nameLength + extraLength + commentLength
  }

  return entries
}

fs.mkdirSync(resourcesDir, { recursive: true })
fs.rmSync(dbPath, { force: true })
fs.rmSync(`${dbPath}-wal`, { force: true })
fs.rmSync(`${dbPath}-shm`, { force: true })

const db = new DatabaseSync(dbPath)
db.exec(`
  PRAGMA journal_mode = OFF;
  PRAGMA synchronous = OFF;
  PRAGMA temp_store = MEMORY;
  PRAGMA auto_vacuum = INCREMENTAL;
  PRAGMA page_size = 4096;

  CREATE TABLE books (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    content TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active', 'deleted')),
    byte_size INTEGER NOT NULL,
    has_info INTEGER NOT NULL DEFAULT 0,
    tags TEXT NOT NULL DEFAULT '',
    summary TEXT NOT NULL DEFAULT ''
  );

  CREATE INDEX idx_books_status_name ON books(status, name COLLATE NOCASE);

  CREATE VIRTUAL TABLE books_fts USING fts5(
    name,
    content,
    content='books',
    content_rowid='id',
    tokenize='trigram'
  );

  CREATE TABLE favorites (
    book_name TEXT PRIMARY KEY NOT NULL
  );

  CREATE TABLE recent (
    book_name TEXT PRIMARY KEY NOT NULL,
    timestamp_ms INTEGER NOT NULL
  );

  CREATE TABLE preferences (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
  );
`)

const insertBook = db.prepare(`
  INSERT INTO books(name, content, status, byte_size, has_info, tags, summary)
  VALUES (?, ?, ?, ?, ?, ?, ?)
  RETURNING id
`)
const insertFts = db.prepare('INSERT INTO books_fts(rowid, name, content) VALUES (?, ?, ?)')
const insertFavorite = db.prepare('INSERT OR IGNORE INTO favorites(book_name) VALUES (?)')
const insertRecent = db.prepare('INSERT OR REPLACE INTO recent(book_name, timestamp_ms) VALUES (?, ?)')
const insertPreference = db.prepare('INSERT OR REPLACE INTO preferences(key, value) VALUES (?, ?)')

const entries = readCentralDirectory()
const activePrefix = 'theReader/public/books/'
const deletedPrefix = 'theReader/public/deleted/'
let activeCount = 0
let deletedCount = 0
let seedConfig = {}

db.exec('BEGIN IMMEDIATE')
try {
  for (const entry of entries) {
    if (entry.path === 'theReader/config.json') {
      seedConfig = JSON.parse(textFromData(readEntryData(entry)))
      continue
    }

    const isActive = entry.path.startsWith(activePrefix) && entry.path.endsWith('.txt')
    const isDeleted = entry.path.startsWith(deletedPrefix) && entry.path.endsWith('.txt')
    if (!isActive && !isDeleted) {
      continue
    }

    const prefix = isActive ? activePrefix : deletedPrefix
    const fileName = entry.path.slice(prefix.length)
    const name = fileName.slice(0, -4)
    const content = textFromData(readEntryData(entry))
    const lines = content.slice(0, 2048).split(/\r?\n/)
    const firstLine = lines[0]?.trim() || ''
    const secondLine = lines[1]?.trim() || ''
    const hasInfo = firstLine.includes('【标签】')
    const tags = hasInfo ? firstLine.replace('【标签】', '').trim() : ''
    const summary = hasInfo ? secondLine.replace('【简介】', '').trim() : ''

    const row = insertBook.get(
      name,
      content,
      isActive ? 'active' : 'deleted',
      entry.uncompressedSize,
      hasInfo ? 1 : 0,
      tags,
      summary
    )
    insertFts.run(row.id, name, content)

    if (isActive) {
      activeCount += 1
    } else {
      deletedCount += 1
    }
  }

  for (const name of seedConfig.favorites || []) {
    insertFavorite.run(name)
  }
  for (const item of seedConfig.recent || []) {
    if (item?.name && Number.isFinite(item.timestamp)) {
      insertRecent.run(item.name, item.timestamp)
    }
  }

  insertPreference.run('fontSize', String(seedConfig.fontSize ?? 18))
  insertPreference.run('recentLimit', String(seedConfig.recentLimit ?? 20))
  insertPreference.run('searchMode', seedConfig.searchMode || 'fulltext')
  insertPreference.run('searchResultLimit', String(seedConfig.searchResultLimit ?? 50))
  insertPreference.run('schemaVersion', '1')

  db.exec('COMMIT')
} catch (error) {
  db.exec('ROLLBACK')
  throw error
}

db.exec(`
  PRAGMA user_version = 1;
  PRAGMA optimize;
  VACUUM;
`)
db.close()

const size = fs.statSync(dbPath).size
console.log(`active=${activeCount}`)
console.log(`deleted=${deletedCount}`)
console.log(`db=${dbPath}`)
console.log(`size=${(size / 1024 / 1024).toFixed(1)} MiB`)

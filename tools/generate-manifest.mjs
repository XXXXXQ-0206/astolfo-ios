import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const zipPath = process.argv[2] || path.resolve(root, '..', '..', 'Desktop', 'theReader.zip')
const resourcesDir = path.resolve(root, 'App', 'Resources')
const manifestPath = path.resolve(resourcesDir, 'BooksManifest.json')
const seedConfigPath = path.resolve(resourcesDir, 'SeedConfig.json')

const bytes = fs.readFileSync(zipPath)
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

function readEntryData(entry) {
  const localOffset = entry.localHeaderOffset
  if (bytes.readUInt32LE(localOffset) !== 0x04034b50) {
    throw new Error(`Bad local header for ${entry.path}`)
  }

  const localNameLength = bytes.readUInt16LE(localOffset + 26)
  const localExtraLength = bytes.readUInt16LE(localOffset + 28)
  const dataOffset = localOffset + 30 + localNameLength + localExtraLength
  const compressed = bytes.subarray(dataOffset, dataOffset + entry.compressedSize)

  if (entry.method === 0) {
    return { data: compressed, dataOffset }
  }
  if (entry.method === 8) {
    return { data: zlib.inflateRawSync(compressed), dataOffset }
  }
  throw new Error(`Unsupported compression method ${entry.method} for ${entry.path}`)
}

function textFromData(data) {
  const text = utf8.decode(data)
  if (!text.includes('\uFFFD')) {
    return text
  }
  return gb18030.decode(data)
}

const eocd = findEndOfCentralDirectory(bytes)
const entryCount = bytes.readUInt16LE(eocd + 10)
const centralDirectoryOffset = bytes.readUInt32LE(eocd + 16)
let offset = centralDirectoryOffset

const manifest = {
  generatedAt: new Date().toISOString(),
  sourceZipName: 'TheReaderSeed.zip',
  books: [],
  deleted: []
}
let seedConfig = null

for (let i = 0; i < entryCount; i += 1) {
  if (bytes.readUInt32LE(offset) !== 0x02014b50) {
    throw new Error(`Bad central directory header at ${offset}`)
  }

  const flags = bytes.readUInt16LE(offset + 8)
  const method = bytes.readUInt16LE(offset + 10)
  const compressedSize = bytes.readUInt32LE(offset + 20)
  const uncompressedSize = bytes.readUInt32LE(offset + 24)
  const nameLength = bytes.readUInt16LE(offset + 28)
  const extraLength = bytes.readUInt16LE(offset + 30)
  const commentLength = bytes.readUInt16LE(offset + 32)
  const localHeaderOffset = bytes.readUInt32LE(offset + 42)
  const rawName = bytes.subarray(offset + 46, offset + 46 + nameLength)
  const entryPath = decodeName(rawName, flags)

  const entry = {
    path: entryPath,
    method,
    compressedSize,
    uncompressedSize,
    localHeaderOffset
  }

  if (entryPath === 'theReader/config.json') {
    const { data } = readEntryData(entry)
    seedConfig = JSON.parse(textFromData(data))
  }

  const activePrefix = 'theReader/public/books/'
  const deletedPrefix = 'theReader/public/deleted/'
  const isBook = entryPath.startsWith(activePrefix) && entryPath.endsWith('.txt')
  const isDeleted = entryPath.startsWith(deletedPrefix) && entryPath.endsWith('.txt')

  if (isBook || isDeleted) {
    const { data, dataOffset } = readEntryData(entry)
    const prefix = isBook ? activePrefix : deletedPrefix
    const fileName = entryPath.slice(prefix.length)
    const name = fileName.slice(0, -4)
    const firstBytes = data.subarray(0, Math.min(data.length, 2048))
    const preview = textFromData(firstBytes)
    const lines = preview.split(/\r?\n/)
    const firstLine = lines[0]?.trim() || ''
    const secondLine = lines[1]?.trim() || ''
    const hasInfo = firstLine.includes('【标签】')

    const item = {
      name,
      path: entryPath,
      dataOffset,
      byteSize: uncompressedSize,
      compressedSize,
      method,
      hasInfo,
      tags: hasInfo ? firstLine.replace('【标签】', '').trim() : '',
      summary: hasInfo ? secondLine.replace('【简介】', '').trim() : ''
    }

    if (isBook) {
      manifest.books.push(item)
    } else {
      manifest.deleted.push(item)
    }
  }

  offset += 46 + nameLength + extraLength + commentLength
}

fs.mkdirSync(resourcesDir, { recursive: true })
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
fs.writeFileSync(seedConfigPath, `${JSON.stringify(seedConfig || {}, null, 2)}\n`)

console.log(`books=${manifest.books.length}`)
console.log(`deleted=${manifest.deleted.length}`)
console.log(`manifest=${manifestPath}`)
console.log(`seedConfig=${seedConfigPath}`)

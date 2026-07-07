import UIKit
import SQLite3
import Darwin
import Foundation

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        runImportPreparationIfNeeded()
        if startChunkAssemblyIfNeeded() {
            return true
        }
        runDatabaseSelfCheckIfNeeded()
        configureAppearance()

        let loadingViewController = LoadingViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = loadingViewController
        window.makeKeyAndVisible()
        self.window = window

        ReaderStore.shared.load { [weak self, weak loadingViewController] result in
            switch result {
            case .success:
                self?.window?.rootViewController = RootNavigationController(store: .shared)
            case .failure(let error):
                loadingViewController?.show(error: error)
            }
        }

        return true
    }

    private func startChunkAssemblyIfNeeded() -> Bool {
        guard CommandLine.arguments.contains("--assemble-import-chunks") else { return false }
        let loadingViewController = LoadingViewController()
        loadingViewController.view.backgroundColor = .readerBackground
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = loadingViewController
        window.makeKeyAndVisible()
        self.window = window

        DispatchQueue.global(qos: .utility).async {
            do {
                try SQLiteStore.assembleChunkedDatabaseIfNeeded()
                print("THE_READER_IMPORT_CHUNKS_ASSEMBLE_OK")
                exit(EXIT_SUCCESS)
            } catch {
                print("THE_READER_IMPORT_CHUNKS_ASSEMBLE_FAILED \(error)")
                exit(EXIT_FAILURE)
            }
        }
        return true
    }

    private func runImportPreparationIfNeeded() {
        if CommandLine.arguments.contains("--remove-library-database") {
            do {
                try SQLiteStore.removeLibraryDatabaseFiles()
                print("THE_READER_LIBRARY_DATABASE_REMOVED")
                exit(EXIT_SUCCESS)
            } catch {
                print("THE_READER_LIBRARY_DATABASE_REMOVE_FAILED \(error)")
                exit(EXIT_FAILURE)
            }
        }
        if CommandLine.arguments.contains("--remove-state-database") {
            do {
                try SQLiteStore.removeStateDatabaseFiles()
                print("THE_READER_STATE_DATABASE_REMOVED")
                exit(EXIT_SUCCESS)
            } catch {
                print("THE_READER_STATE_DATABASE_REMOVE_FAILED \(error)")
                exit(EXIT_FAILURE)
            }
        }
        if CommandLine.arguments.contains("--check-import-storage") {
            do {
                let report = try SQLiteStore.importStorageReport()
                print(report)
                exit(EXIT_SUCCESS)
            } catch {
                print("THE_READER_IMPORT_STORAGE_CHECK_FAILED \(error)")
                exit(EXIT_FAILURE)
            }
        }
        guard CommandLine.arguments.contains("--prepare-import-chunks") else { return }
        do {
            try SQLiteStore.prepareImportChunksDirectory()
            print("THE_READER_IMPORT_CHUNKS_READY")
            exit(EXIT_SUCCESS)
        } catch {
            print("THE_READER_IMPORT_CHUNKS_FAILED \(error)")
            exit(EXIT_FAILURE)
        }
    }

    private func runDatabaseSelfCheckIfNeeded() {
        guard CommandLine.arguments.contains("--database-self-check") else { return }
        do {
            print("THE_READER_DATABASE_CHECK_OPENING")
            let database = try SQLiteStore()
            print("THE_READER_DATABASE_CHECK_OPENED")
            try database.assertWritable()
            print("THE_READER_DATABASE_CHECK_STATE_WRITABLE")
            if CommandLine.arguments.contains("--state-write-probe") {
                try database.writeStateProbe()
                print("THE_READER_STATE_WRITE_PROBE_OK")
            }
            if CommandLine.arguments.contains("--state-read-probe") {
                try database.assertStateProbeAndClear()
                print("THE_READER_STATE_READ_PROBE_OK")
            }
            let activeCount = try database.bookCount(status: .active)
            let deletedCount = try database.bookCount(status: .deleted)
            let stateMode = database.isUsingPersistentState ? "persistent" : "memory"
            print("THE_READER_DATABASE_OK active=\(activeCount) deleted=\(deletedCount) state=\(stateMode)")
            exit(EXIT_SUCCESS)
        } catch {
            print("THE_READER_DATABASE_FAILED \(error)")
            exit(EXIT_FAILURE)
        }
    }

    private func configureAppearance() {
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        navigationAppearance.backgroundColor = UIColor.readerBackground.withAlphaComponent(0.16)
        navigationAppearance.shadowColor = .clear
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.readerText]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.readerText]
        let navigationEdgeAppearance = UINavigationBarAppearance()
        navigationEdgeAppearance.configureWithTransparentBackground()
        navigationEdgeAppearance.backgroundColor = UIColor.readerBackground.withAlphaComponent(0.0)
        navigationEdgeAppearance.shadowColor = .clear
        navigationEdgeAppearance.titleTextAttributes = [.foregroundColor: UIColor.readerText]
        navigationEdgeAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.readerText]
        UINavigationBar.appearance().prefersLargeTitles = true
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationEdgeAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        toolbarAppearance.backgroundColor = UIColor.readerPanel.withAlphaComponent(0.24)
        toolbarAppearance.shadowColor = .clear
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance

        UITableView.appearance().backgroundColor = .readerBackground
        UITableViewCell.appearance().backgroundColor = .readerBackground
        UIView.appearance().tintColor = .readerAction
        UINavigationBar.appearance().tintColor = .readerAction
        UIToolbar.appearance().tintColor = .readerAction
        UIBarButtonItem.appearance().tintColor = .readerAction
        UIStepper.appearance().tintColor = .readerAction
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.readerAction.withAlphaComponent(0.2)
    }
}

extension UIColor {
    static let readerBackground = UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
    static let readerPanel = UIColor(red: 44 / 255, green: 44 / 255, blue: 46 / 255, alpha: 1)
    static let readerControl = UIColor(red: 58 / 255, green: 58 / 255, blue: 60 / 255, alpha: 1)
    static let readerPressed = UIColor(red: 72 / 255, green: 72 / 255, blue: 74 / 255, alpha: 1)
    static let readerText = UIColor(red: 209 / 255, green: 209 / 255, blue: 214 / 255, alpha: 1)
    static let readerSecondary = UIColor(red: 142 / 255, green: 142 / 255, blue: 147 / 255, alpha: 1)
    static let readerSeparator = UIColor.white.withAlphaComponent(0.15)
    static let readerAction = UIColor(red: 204 / 255, green: 204 / 255, blue: 210 / 255, alpha: 1)
    static let readerHighlight = UIColor(red: 86 / 255, green: 166 / 255, blue: 255 / 255, alpha: 1)
}

private func compactNavigationItem(
    target: Any?,
    items: [(systemName: String, action: Selector)],
    menuItems: [(systemName: String, menu: UIMenu)] = []
) -> UIBarButtonItem {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = 2

    for item in items {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: item.systemName), for: .normal)
        button.tintColor = .readerAction
        button.addTarget(target, action: item.action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        stackView.addArrangedSubview(button)
    }

    for item in menuItems {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: item.systemName), for: .normal)
        button.tintColor = .readerAction
        button.menu = item.menu
        button.showsMenuAsPrimaryAction = true
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        stackView.addArrangedSubview(button)
    }

    return UIBarButtonItem(customView: stackView)
}

struct Book: Identifiable, Hashable {
    let id: Int64
    let name: String
    let status: BookStatus
    let byteSize: Int64
    let hasInfo: Bool
    let tags: String
    let summary: String
}

enum BookStatus: String {
    case active
    case deleted
}

enum BookSortMode: String {
    case name
    case sizeDescending
    case sizeAscending

    var title: String {
        switch self {
        case .name:
            return "按名称"
        case .sizeDescending:
            return "从大到小"
        case .sizeAscending:
            return "从小到大"
        }
    }
}

struct RecentBook: Hashable {
    let name: String
    let timestamp: Int64
}

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let bookName: String
    let snippet: String
}

struct SearchPreset: Hashable {
    let query: String
    let updatedAt: Int64
}

struct SearchProgress: Equatable {
    let total: Int
    let searched: Int
    let matched: Int
    let unit: String

    var remaining: Int {
        max(total - searched, 0)
    }
}

private enum SearchCancellation: Error {
    case cancelled
}

private final class SearchCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

private struct SearchTermGroup {
    let term: String
    let alternatives: [String]
}

private enum BookOrdering {
    private static let fallbackLocale = Locale(identifier: "zh-Hans")
    private static let cacheLock = NSLock()
    private static var cachedSortKeys: [String: String] = [:]

    static func nameAscending(_ lhs: String, _ rhs: String) -> Bool {
        compareNames(lhs, rhs) == .orderedAscending
    }

    static func compareNames(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsKey = sortKey(for: lhs)
        let rhsKey = sortKey(for: rhs)
        let comparison = lhsKey.compare(rhsKey, options: [.caseInsensitive, .diacriticInsensitive, .numeric])
        if comparison != .orderedSame {
            return comparison
        }
        return lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive, .numeric], range: nil, locale: fallbackLocale)
    }

    private static func sortKey(for value: String) -> String {
        cacheLock.lock()
        if let cached = cachedSortKeys[value] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let mutable = NSMutableString(string: trimmed) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        let folded = (mutable as String).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: fallbackLocale)
        let key = folded
            .replacingOccurrences(of: #"^[\p{P}\p{S}\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cacheLock.lock()
        cachedSortKeys[value] = key
        cacheLock.unlock()
        return key
    }
}

private enum SearchText {
    static let gbkEncoding = CFStringEncoding(CFStringEncodings.GBK_95.rawValue)
    static let gb18030Encoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    private static let mojibakeMarkers = ["銆", "涓", "鍦", "鐨", "绛", "浠", "嬨", "€�", "�", "鍒", "簳", "鍢", "樆"]

    static func canonicalTerms(in value: String) -> [String] {
        let rawTerms = value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        var uniqueTerms: [String] = []
        for term in rawTerms where !uniqueTerms.contains(where: { same($0, term) }) {
            uniqueTerms.append(term)
        }

        return uniqueTerms.filter { term in
            !uniqueTerms.contains { other in
                !same(term, other) && contains(other, term)
            }
        }
    }

    static func normalizedQuery(_ value: String) -> String {
        canonicalTerms(in: value).joined(separator: " ")
    }

    static func query(_ query: String, containsPreset preset: String) -> Bool {
        let queryTerms = canonicalTerms(in: query)
        let presetTerms = canonicalTerms(in: preset)
        guard !queryTerms.isEmpty, !presetTerms.isEmpty else { return false }
        return presetTerms.allSatisfy { presetTerm in
            queryTerms.contains { queryTerm in
                same(queryTerm, presetTerm) || contains(queryTerm, presetTerm)
            }
        }
    }

    static func termGroups(in value: String) -> [SearchTermGroup] {
        canonicalTerms(in: value).map { term in
            var alternatives = [term]
            if let mojibake = mojibakeVariant(of: term), !mojibake.isEmpty, !same(mojibake, term) {
                alternatives.append(mojibake)
            }
            return SearchTermGroup(term: term, alternatives: alternatives)
        }
    }

    static func repairMojibakeIfNeeded(_ value: String) -> String {
        let originalMarkers = mojibakeMarkerCount(value)
        let replacementCount = value.filter({ $0 == "\u{fffd}" }).count
        let shouldAttempt =
            originalMarkers >= 3 ||
            replacementCount >= 3 ||
            (value.count <= 12 && looksLikeShortMojibake(value))
        guard shouldAttempt else { return value }
        let candidates = mojibakeCandidates(for: value)
        let originalCJK = cjkCount(value)
        let minReadableCJK = max(2, originalCJK / 4)
        let originalLength = value.count
        let eligible = candidates.filter { cjkCount($0) >= minReadableCJK }
        guard let best = eligible.min(by: {
            mojibakeCandidateScore($0, originalLength: originalLength) < mojibakeCandidateScore($1, originalLength: originalLength)
        }) else { return value }
        let bestMarkers = mojibakeMarkerCount(best)
        let bestCJK = cjkCount(best)
        if best != value, bestMarkers < originalMarkers, bestCJK >= minReadableCJK {
            return best
        }
        if best != value, bestMarkers <= max(1, originalMarkers / 5), bestCJK >= minReadableCJK {
            return best
        }
        return value
    }

    static func forceRepairMojibake(_ value: String) -> String {
        let candidates = mojibakeCandidates(for: value)
        guard candidates.count > 1 else { return value }
        let originalMarkers = mojibakeMarkerCount(value)
        let originalCJK = cjkCount(value)
        let minReadableCJK = max(1, originalCJK / 3)
        let originalLength = value.count
        let eligible = candidates.filter { candidate in
            !candidate.isEmpty && cjkCount(candidate) >= minReadableCJK && abs(candidate.count - originalLength) <= max(6, originalLength * 2)
        }
        guard let best = eligible.min(by: {
            mojibakeCandidateScore($0, originalLength: originalLength) < mojibakeCandidateScore($1, originalLength: originalLength)
        }) else { return value }
        if best != value, mojibakeCandidateScore(best, originalLength: originalLength) < mojibakeCandidateScore(value, originalLength: originalLength) {
            return best
        }
        let bestMarkers = mojibakeMarkerCount(best)
        let bestCJK = cjkCount(best)
        if best != value, bestMarkers < originalMarkers {
            return best
        }
        if best != value, value.count <= 12, bestMarkers <= originalMarkers, bestCJK >= minReadableCJK {
            return best
        }
        return repairMojibakeIfNeeded(value)
    }

    private static func mojibakeCandidates(for value: String) -> [String] {
        var candidates = [value]
        for encoding in [gb18030Encoding, gbkEncoding] {
            if let data = CFStringCreateExternalRepresentation(nil, value as CFString, encoding, 0) as Data?,
               let repaired = String(data: data, encoding: .utf8) {
                candidates.append(repaired)
            }
            if let data = CFStringCreateExternalRepresentation(nil, value as CFString, encoding, UInt8(ascii: "?")) as Data? {
                let repaired = String(decoding: data, as: UTF8.self)
                    .replacingOccurrences(of: "\u{fffd}", with: "")
                if !repaired.isEmpty {
                    candidates.append(repaired)
                }
            }
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func mojibakeVariant(of term: String) -> String? {
        let bytes = Array(term.utf8)
        return CFStringCreateWithBytes(nil, bytes, bytes.count, gbkEncoding, false) as String?
    }

    private static func same(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func contains(_ container: String, _ value: String) -> Bool {
        container.range(of: value, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func looksLikeMojibake(_ value: String) -> Bool {
        mojibakeMarkerCount(value) >= 3
    }

    private static func looksLikeShortMojibake(_ value: String) -> Bool {
        let markerCount = mojibakeMarkerCount(value)
        guard markerCount > 0 else { return false }
        let cjk = cjkCount(value)
        return value.count <= 12 && cjk > 0 && markerCount * 2 >= cjk
    }

    private static func mojibakeScore(_ value: String) -> Int {
        mojibakeMarkerCount(value) * 10000 + value.filter { $0 == "\u{fffd}" }.count * 1000 - cjkCount(value)
    }

    private static func mojibakeCandidateScore(_ value: String, originalLength: Int) -> Int {
        mojibakeScore(value) + abs(value.count - originalLength)
    }

    private static func mojibakeMarkerCount(_ value: String) -> Int {
        mojibakeMarkers.reduce(0) { score, marker in
            score + value.components(separatedBy: marker).count - 1
        }
    }

    private static func cjkCount(_ value: String) -> Int {
        value.prefix(8000).reduce(0) { count, character in
            guard let scalar = character.unicodeScalars.first else { return count }
            return (0x4e00...0x9fff).contains(Int(scalar.value)) ? count + 1 : count
        }
    }
}

enum Route: Hashable {
    case recent
    case favorites
    case settings
    case trash
    case reader(String)
}

final class SQLiteStore: @unchecked Sendable {
    private static let catalogVersion = "4"
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    private(set) var isUsingPersistentState = false
    private(set) var stateWarning: String?
    private var hasBigramFTS = false
    private var hasCatalog = false

    private struct ChunkManifest: Decodable {
        let partCount: Int
        let totalBytes: Int64
    }

    init() throws {
        let dbURL = try Self.databaseURL()
        let stateURL = try Self.stateURL()
        if !FileManager.default.fileExists(atPath: dbURL.path) {
            throw DatabaseError.message("未找到书库数据库。请把 Books.sqlite 放入：\(dbURL.path)")
        }

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI
        guard sqlite3_open_v2(":memory:", &db, flags, nil) == SQLITE_OK else {
            let message = db.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "Unable to open database"
            if let db {
                sqlite3_close(db)
            }
            db = nil
            throw DatabaseError.message(message)
        }

        sqlite3_busy_timeout(db, 5000)
        try attachDatabase(at: dbURL, as: "library", mode: "rwc")
        hasBigramFTS = (try? libraryTableExists("books_bigram_fts")) ?? false
        try attachStateDatabase(at: stateURL)
        try configurePragmas()
        try initializeStateSchema()
        try migrateSeedStateIfNeeded()
        try ensureBookCatalog()
        hasCatalog = (try? tableExists(in: "state", named: "book_catalog")) ?? false
    }

    private func configurePragmas() throws {
        try? exec("PRAGMA state.journal_mode=WAL;")
        try exec("PRAGMA state.synchronous=NORMAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA foreign_keys=ON;")
        try exec("PRAGMA case_sensitive_like=ON;")
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func interrupt() {
        sqlite3_interrupt(db)
    }

    private static func databaseURL() throws -> URL {
        let fileManager = FileManager.default
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("TheReader", isDirectory: true)
        let legacyURL = base.appendingPathComponent("Books.sqlite")
        let dbURL = folder.appendingPathComponent("Books.sqlite")

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            try? fileManager.moveItem(at: folder, to: legacyURL)
        }

        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: folder.path)
        if !fileManager.fileExists(atPath: dbURL.path), fileManager.fileExists(atPath: legacyURL.path) {
            try fileManager.moveItem(at: legacyURL, to: dbURL)
        }
        if fileManager.fileExists(atPath: dbURL.path) {
            try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dbURL.path)
        }

        return dbURL
    }

    private static func stateURL() throws -> URL {
        let fileManager = FileManager.default
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = documents.appendingPathComponent("TheReader", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: folder.path)
        return folder.appendingPathComponent("ReaderState.sqlite")
    }

    static func prepareImportChunksDirectory() throws {
        let folder = try importChunksDirectoryURL(create: false)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
        }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: folder.path)
    }

    static func removeLibraryDatabaseFiles() throws {
        let dbURL = try databaseURL()
        let fileManager = FileManager.default
        let urls = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-wal"),
            URL(fileURLWithPath: dbURL.path + "-shm"),
            dbURL.deletingLastPathComponent().appendingPathComponent("Books.sqlite.importing"),
        ]
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func removeStateDatabaseFiles() throws {
        let stateURL = try stateURL()
        let fileManager = FileManager.default
        let urls = [
            stateURL,
            URL(fileURLWithPath: stateURL.path + "-wal"),
            URL(fileURLWithPath: stateURL.path + "-shm"),
        ]
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    static func importStorageReport() throws -> String {
        let fileManager = FileManager.default
        let chunkFolder = try importChunksDirectoryURL(create: false)
        let manifestURL = chunkFolder.appendingPathComponent("Books.sqlite.manifest.json")
        var chunkCount = 0
        var chunkBytes: Int64 = 0
        if fileManager.fileExists(atPath: chunkFolder.path) {
            let urls = try fileManager.contentsOfDirectory(at: chunkFolder, includingPropertiesForKeys: [.fileSizeKey])
            for url in urls where url.lastPathComponent.hasPrefix("Books.sqlite.part-") {
                chunkCount += 1
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                chunkBytes += Int64(values.fileSize ?? 0)
            }
        }
        let dbURL = try databaseURL()
        let dbExists = fileManager.fileExists(atPath: dbURL.path)
        let tmpURL = dbURL.deletingLastPathComponent().appendingPathComponent("Books.sqlite.importing")
        let tmpExists = fileManager.fileExists(atPath: tmpURL.path)
        let values = try dbURL.deletingLastPathComponent().resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        let important = values.volumeAvailableCapacityForImportantUsage ?? -1
        let available = Int64(values.volumeAvailableCapacity ?? -1)
        return "THE_READER_IMPORT_STORAGE chunks=\(chunkCount) chunkBytes=\(chunkBytes) manifest=\(fileManager.fileExists(atPath: manifestURL.path)) dbExists=\(dbExists) tmpExists=\(tmpExists) available=\(available) importantAvailable=\(important)"
    }

    private static func importChunksDirectoryURL(create: Bool) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = documents
            .appendingPathComponent("TheReader", isDirectory: true)
            .appendingPathComponent("ImportChunks", isDirectory: true)
        if create {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: folder.path)
        }
        return folder
    }

    static func assembleChunkedDatabaseIfNeeded() throws {
        let fileManager = FileManager.default
        let chunkFolder = try importChunksDirectoryURL(create: false)
        let manifestURL = chunkFolder.appendingPathComponent("Books.sqlite.manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { return }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ChunkManifest.self, from: manifestData)
        guard manifest.partCount > 0, manifest.totalBytes > 0 else { return }

        let partURLs = (0..<manifest.partCount).map { index in
            chunkFolder.appendingPathComponent(String(format: "Books.sqlite.part-%04d", index))
        }
        guard partURLs.allSatisfy({ fileManager.fileExists(atPath: $0.path) }) else { return }

        let copiedBytes = try partURLs.reduce(Int64(0)) { total, url in
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return total + ((attributes[.size] as? NSNumber)?.int64Value ?? 0)
        }
        guard copiedBytes == manifest.totalBytes else { return }

        let dbURL = try databaseURL()
        let tmpURL = dbURL.deletingLastPathComponent().appendingPathComponent("Books.sqlite.importing")
        if fileManager.fileExists(atPath: tmpURL.path) {
            try fileManager.removeItem(at: tmpURL)
        }
        print("THE_READER_IMPORT_CHUNKS_ASSEMBLE_START parts=\(manifest.partCount) bytes=\(manifest.totalBytes)")
        try fileManager.moveItem(at: partURLs[0], to: tmpURL)
        var writtenBytes = (try fileManager.attributesOfItem(atPath: tmpURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        let output = try FileHandle(forWritingTo: tmpURL)
        output.seekToEndOfFile()
        do {
            for (partOffset, partURL) in partURLs.dropFirst().enumerated() {
                let input = try FileHandle(forReadingFrom: partURL)
                while true {
                    var didReachEnd = false
                    autoreleasepool {
                        let data = input.readData(ofLength: 1024 * 1024)
                        if data.isEmpty {
                            didReachEnd = true
                        } else {
                            output.write(data)
                            writtenBytes += Int64(data.count)
                        }
                    }
                    if didReachEnd { break }
                }
                try input.close()
                try fileManager.removeItem(at: partURL)
                print("THE_READER_IMPORT_CHUNKS_ASSEMBLED_PART index=\(partOffset + 1) bytes=\(writtenBytes)")
            }
            try output.close()
        } catch {
            try? output.close()
            try? fileManager.removeItem(at: tmpURL)
            throw error
        }
        guard writtenBytes == manifest.totalBytes else {
            try? fileManager.removeItem(at: tmpURL)
            return
        }

        if fileManager.fileExists(atPath: dbURL.path) {
            try fileManager.removeItem(at: dbURL)
        }
        try fileManager.moveItem(at: tmpURL, to: dbURL)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dbURL.path)
        try? fileManager.removeItem(at: chunkFolder)
        print("THE_READER_IMPORT_CHUNKS_ASSEMBLED bytes=\(writtenBytes)")
    }

    private static func ensureStateDatabase(at stateURL: URL) throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var stateDB: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(stateURL.path, &stateDB, flags, nil) == SQLITE_OK else {
            let message = stateDB.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "Unable to open state database"
            let code = stateDB.map { sqlite3_extended_errcode($0) } ?? -1
            if let stateDB {
                sqlite3_close(stateDB)
            }
            throw DatabaseError.message("unable to open state database: \(stateURL.path) (\(message), code \(code))")
        }
        sqlite3_close(stateDB)

        if FileManager.default.fileExists(atPath: stateURL.path) {
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: stateURL.path)
        }
    }

    private static func sqliteURI(for url: URL, mode: String) -> String {
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path
        return "file:\(encodedPath)?mode=\(mode)"
    }

    private func attachDatabase(at url: URL, as schema: String, mode: String) throws {
        let statement = try prepare("ATTACH DATABASE ? AS \(schema)")
        defer { sqlite3_finalize(statement) }
        bind(Self.sqliteURI(for: url, mode: mode), to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
    }

    private func attachMemoryDatabase(as schema: String) throws {
        let statement = try prepare("ATTACH DATABASE ':memory:' AS \(schema)")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
    }

    private func libraryTableExists(_ name: String) throws -> Bool {
        try tableExists(in: "library", named: name)
    }

    private func tableExists(in schema: String, named name: String) throws -> Bool {
        let statement = try prepare("SELECT 1 FROM \(schema).sqlite_master WHERE type = 'table' AND name = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func attachStateDatabase(at stateURL: URL) throws {
        do {
            try Self.ensureStateDatabase(at: stateURL)
            try attachDatabase(at: stateURL, as: "state", mode: "rwc")
            isUsingPersistentState = true
            stateWarning = nil
        } catch {
            let message = "ReaderState persistent database unavailable, using in-memory state: \(error)"
            print(message)
            try attachMemoryDatabase(as: "state")
            isUsingPersistentState = false
            stateWarning = "状态库不可写，本次启动后的收藏、最近阅读和设置不会持久保存。\(error)"
        }
    }

    private func initializeStateSchema() throws {
        try exec("""
            CREATE TABLE IF NOT EXISTS state.preferences (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            )
        """)
        try exec("""
            CREATE TABLE IF NOT EXISTS state.favorites (
                book_name TEXT PRIMARY KEY NOT NULL
            )
        """)
        try exec("""
            CREATE TABLE IF NOT EXISTS state.recent (
                book_name TEXT PRIMARY KEY NOT NULL,
                timestamp_ms INTEGER NOT NULL
            )
        """)
        try exec("""
            CREATE TABLE IF NOT EXISTS state.book_status (
                book_name TEXT PRIMARY KEY NOT NULL,
                status TEXT NOT NULL CHECK (status IN ('active', 'deleted'))
            )
        """)
        try exec("""
            CREATE TABLE IF NOT EXISTS state.deleted_books (
                book_name TEXT PRIMARY KEY NOT NULL
            )
        """)
        try exec("""
            CREATE TABLE IF NOT EXISTS state.book_catalog (
                sort_order INTEGER PRIMARY KEY NOT NULL,
                name TEXT NOT NULL UNIQUE,
                status TEXT NOT NULL CHECK (status IN ('active', 'deleted')),
                byte_size INTEGER NOT NULL,
                has_info INTEGER NOT NULL DEFAULT 0,
                tags TEXT NOT NULL DEFAULT '',
                summary TEXT NOT NULL DEFAULT ''
            )
        """)
        try exec("CREATE INDEX IF NOT EXISTS state.idx_book_catalog_status_name ON book_catalog(status, name COLLATE NOCASE)")
        try exec("""
            CREATE TABLE IF NOT EXISTS state.search_presets (
                query TEXT PRIMARY KEY NOT NULL,
                updated_at INTEGER NOT NULL
            )
        """)
        try exec("""
            CREATE TABLE IF NOT EXISTS state.search_preset_entries (
                query TEXT NOT NULL,
                book_name TEXT NOT NULL,
                snippet TEXT NOT NULL DEFAULT '',
                sort_order INTEGER NOT NULL,
                PRIMARY KEY(query, book_name)
            )
        """)
        try exec("CREATE INDEX IF NOT EXISTS state.idx_search_preset_entries_query_order ON search_preset_entries(query, sort_order)")
    }

    private func migrateSeedStateIfNeeded() throws {
        let marker = "__state_seeded_from_library__"
        let markerCheck = try prepare("SELECT value FROM state.preferences WHERE key = ? LIMIT 1")
        defer { sqlite3_finalize(markerCheck) }
        bind(marker, to: markerCheck, at: 1)
        guard sqlite3_step(markerCheck) != SQLITE_ROW else { return }

        try exec("BEGIN IMMEDIATE")
        do {
            if (try? libraryTableExists("favorites")) == true {
                try exec("""
                    INSERT OR IGNORE INTO state.favorites(book_name)
                    SELECT book_name FROM library.favorites
                """)
            }
            if (try? libraryTableExists("recent")) == true {
                try exec("""
                    INSERT OR IGNORE INTO state.recent(book_name, timestamp_ms)
                    SELECT book_name, timestamp_ms FROM library.recent
                """)
            }
            if (try? libraryTableExists("preferences")) == true {
                try exec("""
                    INSERT OR REPLACE INTO state.preferences(key, value)
                    SELECT key, value FROM library.preferences
                """)
            }
            try exec("""
                INSERT OR REPLACE INTO state.preferences(key, value)
                VALUES ('\(Self.sqlLiteral(marker))', '1')
            """)
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    private func ensureBookCatalog() throws {
        let libraryCount: Int
        do {
            let statement = try prepare("SELECT COUNT(*) FROM library.books")
            defer { sqlite3_finalize(statement) }
            libraryCount = try count(from: statement)
        }

        let catalogCount: Int
        do {
            let statement = try prepare("SELECT COUNT(*) FROM state.book_catalog")
            defer { sqlite3_finalize(statement) }
            catalogCount = try count(from: statement)
        }

        let version = try preferenceValue(for: "__book_catalog_version__")
        guard version != Self.catalogVersion || catalogCount != libraryCount else { return }
        try rebuildBookCatalog()
    }

    private func rebuildBookCatalog() throws {
        struct CatalogEntry {
            let name: String
            let status: String
            let byteSize: Int64
            let hasInfo: Int64
            let tags: String
            let summary: String
        }

        let rows = try prepare("""
            SELECT name, status, byte_size, has_info, tags, summary
            FROM library.books
        """)
        defer { sqlite3_finalize(rows) }

        var entries: [CatalogEntry] = []
        while sqlite3_step(rows) == SQLITE_ROW {
            entries.append(
                CatalogEntry(
                    name: columnText(rows, 0),
                    status: columnText(rows, 1),
                    byteSize: columnInt(rows, 2),
                    hasInfo: columnInt(rows, 3),
                    tags: columnText(rows, 4),
                    summary: columnText(rows, 5)
                )
            )
        }

        entries.sort { lhs, rhs in
            let comparison = BookOrdering.compareNames(lhs.name, rhs.name)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }
            return lhs.name < rhs.name
        }

        try exec("BEGIN IMMEDIATE")
        do {
            try exec("DELETE FROM state.book_catalog")
            let insert = try prepare("""
                INSERT INTO state.book_catalog(sort_order, name, status, byte_size, has_info, tags, summary)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """)
            defer { sqlite3_finalize(insert) }
            for (index, entry) in entries.enumerated() {
                sqlite3_reset(insert)
                sqlite3_clear_bindings(insert)
                bind(Int64(index + 1), to: insert, at: 1)
                bind(entry.name, to: insert, at: 2)
                bind(entry.status, to: insert, at: 3)
                bind(entry.byteSize, to: insert, at: 4)
                bind(entry.hasInfo, to: insert, at: 5)
                bind(entry.tags, to: insert, at: 6)
                bind(entry.summary, to: insert, at: 7)
                guard sqlite3_step(insert) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
            }
            try setPreference("__book_catalog_version__", value: Self.catalogVersion)
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    private func preferenceValue(for key: String) throws -> String? {
        let statement = try prepare("SELECT value FROM state.preferences WHERE key = ? LIMIT 1")
        defer { sqlite3_finalize(statement) }
        bind(key, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return columnText(statement, 0)
    }

    private func exec(_ sql: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "SQLite error"
            sqlite3_free(error)
            throw DatabaseError.message(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.message(lastError)
        }
        return statement
    }

    private var lastError: String {
        guard let db, let message = sqlite3_errmsg(db) else { return "SQLite error" }
        return String(cString: message)
    }

    private func bind(_ text: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT)
    }

    private func bind(_ int: Int64, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_int64(statement, index, int)
    }

    func assertWritable() throws {
        lock.lock()
        defer { lock.unlock() }

        try exec("BEGIN IMMEDIATE")
        do {
            let statement = try prepare("INSERT OR REPLACE INTO state.preferences(key, value) VALUES ('__database_self_check__', 'ok')")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
            try exec("ROLLBACK")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func bookCount(status: BookStatus) throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        let sql = hasCatalog
            ? """
            SELECT COUNT(*)
            FROM state.book_catalog AS catalog
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = catalog.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = catalog.name
            WHERE COALESCE(state_status.status, catalog.status) = ?
              AND state_deleted.book_name IS NULL
            """
            : """
            SELECT COUNT(*)
            FROM library.books AS books
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE COALESCE(state_status.status, books.status) = ?
              AND state_deleted.book_name IS NULL
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(status.rawValue, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { throw DatabaseError.message(lastError) }
        return Int(columnInt(statement, 0))
    }

    func writeStateProbe() throws {
        lock.lock()
        defer { lock.unlock() }

        try exec("BEGIN IMMEDIATE")
        do {
            try exec("INSERT OR REPLACE INTO state.preferences(key, value) VALUES ('__state_probe__', 'ok')")
            if hasCatalog {
                try exec("INSERT OR IGNORE INTO state.favorites(book_name) SELECT name FROM state.book_catalog WHERE status = 'active' ORDER BY sort_order LIMIT 1")
            } else {
                try exec("INSERT OR IGNORE INTO state.favorites(book_name) SELECT name FROM library.books WHERE status = 'active' ORDER BY id LIMIT 1")
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func assertStateProbeAndClear() throws {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("SELECT value FROM state.preferences WHERE key = '__state_probe__' LIMIT 1")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, columnText(statement, 0) == "ok" else {
            throw DatabaseError.message("state probe was not persisted")
        }
        try exec("DELETE FROM state.preferences WHERE key = '__state_probe__'")
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        let byteCount = Int(sqlite3_column_bytes(statement, index))
        guard byteCount > 0 else { return "" }
        if let textPointer = sqlite3_column_text(statement, index) {
            let buffer = UnsafeBufferPointer(start: textPointer, count: byteCount)
            return String(decoding: buffer, as: UTF8.self)
        }
        if let blobPointer = sqlite3_column_blob(statement, index) {
            let data = Data(bytes: blobPointer, count: byteCount)
            return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        }
        return ""
    }

    private func columnInt(_ statement: OpaquePointer?, _ index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func books(status: BookStatus, sortMode: BookSortMode = .name) throws -> [Book] {
        lock.lock()
        defer { lock.unlock() }

        let orderSQL = bookOrderSQL(for: sortMode, tableAlias: hasCatalog ? "catalog" : "books", fallbackOrderColumn: hasCatalog ? "sort_order" : "id")
        let sql = hasCatalog
            ? """
            SELECT catalog.sort_order,
                   catalog.name,
                   COALESCE(state_status.status, catalog.status),
                   catalog.byte_size,
                   catalog.has_info,
                   catalog.tags,
                   catalog.summary
            FROM state.book_catalog AS catalog
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = catalog.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = catalog.name
            WHERE COALESCE(state_status.status, catalog.status) = ?
              AND state_deleted.book_name IS NULL
            ORDER BY \(orderSQL)
            """
            : """
            SELECT books.id,
                   books.name,
                   COALESCE(state_status.status, books.status),
                   books.byte_size,
                   books.has_info,
                   books.tags,
                   books.summary
            FROM library.books AS books
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE COALESCE(state_status.status, books.status) = ?
              AND state_deleted.book_name IS NULL
            ORDER BY \(orderSQL)
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(status.rawValue, to: statement, at: 1)

        var result: [Book] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let tags = columnText(statement, 5)
            let summary = columnText(statement, 6)
            result.append(Book(
                id: columnInt(statement, 0),
                name: columnText(statement, 1),
                status: BookStatus(rawValue: columnText(statement, 2)) ?? status,
                byteSize: columnInt(statement, 3),
                hasInfo: columnInt(statement, 4) == 1 || !tags.isEmpty || !summary.isEmpty,
                tags: SearchText.repairMojibakeIfNeeded(tags),
                summary: SearchText.repairMojibakeIfNeeded(summary)
            ))
        }
        return result
    }

    private func bookOrderSQL(for sortMode: BookSortMode, tableAlias: String, fallbackOrderColumn: String) -> String {
        switch sortMode {
        case .name:
            if tableAlias == "catalog" {
                return "\(tableAlias).\(fallbackOrderColumn) ASC"
            }
            return "\(tableAlias).name COLLATE NOCASE ASC, \(tableAlias).\(fallbackOrderColumn) ASC"
        case .sizeDescending:
            if tableAlias == "catalog" {
                return "\(tableAlias).byte_size DESC, \(tableAlias).\(fallbackOrderColumn) ASC"
            }
            return "\(tableAlias).byte_size DESC, \(tableAlias).name COLLATE NOCASE ASC"
        case .sizeAscending:
            if tableAlias == "catalog" {
                return "\(tableAlias).byte_size ASC, \(tableAlias).\(fallbackOrderColumn) ASC"
            }
            return "\(tableAlias).byte_size ASC, \(tableAlias).name COLLATE NOCASE ASC"
        }
    }

    func bookInfo(for name: String) throws -> Book? {
        lock.lock()
        defer { lock.unlock() }

        let sql = hasCatalog
            ? """
            SELECT catalog.sort_order,
                   catalog.name,
                   COALESCE(state_status.status, catalog.status),
                   catalog.byte_size,
                   catalog.has_info,
                   catalog.tags,
                   catalog.summary
            FROM state.book_catalog AS catalog
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = catalog.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = catalog.name
            WHERE catalog.name = ?
              AND state_deleted.book_name IS NULL
            LIMIT 1
            """
            : """
            SELECT books.id,
                   books.name,
                   COALESCE(state_status.status, books.status),
                   books.byte_size,
                   books.has_info,
                   books.tags,
                   books.summary
            FROM library.books AS books
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE books.name = ?
              AND state_deleted.book_name IS NULL
            LIMIT 1
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let status = BookStatus(rawValue: columnText(statement, 2)) ?? .active
        var tags = columnText(statement, 5)
        var summary = columnText(statement, 6)
        if tags.isEmpty, summary.isEmpty, let content = try content(for: name) {
            let parsed = Self.extractBookInfo(from: content)
            tags = parsed.tags
            summary = parsed.summary
        }
        return Book(
            id: columnInt(statement, 0),
            name: columnText(statement, 1),
            status: status,
            byteSize: columnInt(statement, 3),
            hasInfo: columnInt(statement, 4) == 1 || !tags.isEmpty || !summary.isEmpty,
            tags: SearchText.repairMojibakeIfNeeded(tags),
            summary: SearchText.repairMojibakeIfNeeded(summary)
        )
    }

    func content(for name: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("""
            SELECT content
            FROM library.books AS books
            WHERE name = ?
              AND NOT EXISTS (SELECT 1 FROM state.deleted_books WHERE book_name = books.name)
            LIMIT 1
        """)
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return SearchText.repairMojibakeIfNeeded(columnText(statement, 0))
    }

    func rawContent(for name: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("""
            SELECT content
            FROM library.books AS books
            WHERE name = ?
              AND NOT EXISTS (SELECT 1 FROM state.deleted_books WHERE book_name = books.name)
            LIMIT 1
        """)
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return columnText(statement, 0)
    }

    func updateBook(originalName: String, newName rawNewName: String, content rawContent: String) throws -> Book {
        lock.lock()
        defer { lock.unlock() }

        let newName = rawNewName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            throw DatabaseError.message("标题不能为空")
        }
        let content = SearchText.repairMojibakeIfNeeded(rawContent)
        let existing = try prepare("SELECT id, content, status FROM library.books WHERE name = ? LIMIT 1")
        defer { sqlite3_finalize(existing) }
        bind(originalName, to: existing, at: 1)
        guard sqlite3_step(existing) == SQLITE_ROW else {
            throw DatabaseError.message("文件未找到")
        }
        let bookID = columnInt(existing, 0)
        let oldContent = columnText(existing, 1)
        let status = BookStatus(rawValue: columnText(existing, 2)) ?? .active

        if newName != originalName {
            let duplicate = try prepare("SELECT 1 FROM library.books WHERE name = ? LIMIT 1")
            defer { sqlite3_finalize(duplicate) }
            bind(newName, to: duplicate, at: 1)
            if sqlite3_step(duplicate) == SQLITE_ROW {
                throw DatabaseError.message("已存在同名文章")
            }
        }

        let byteSize = Int64(content.data(using: .utf8)?.count ?? 0)
        let parsed = Self.extractBookInfo(from: content)
        let hasInfo = !parsed.tags.isEmpty || !parsed.summary.isEmpty

        try exec("BEGIN IMMEDIATE")
        do {
            let update = try prepare("""
                UPDATE library.books
                SET name = ?, content = ?, byte_size = ?, has_info = ?, tags = ?, summary = ?
                WHERE id = ?
            """)
            defer { sqlite3_finalize(update) }
            bind(newName, to: update, at: 1)
            bind(content, to: update, at: 2)
            bind(byteSize, to: update, at: 3)
            bind(hasInfo ? 1 : 0, to: update, at: 4)
            bind(parsed.tags, to: update, at: 5)
            bind(parsed.summary, to: update, at: 6)
            bind(bookID, to: update, at: 7)
            guard sqlite3_step(update) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            try renameStateReferences(from: originalName, to: newName)
            try updateSearchIndexes(rowID: bookID, oldName: originalName, oldContent: oldContent, newName: newName, newContent: content)
            if hasCatalog {
                try updateCatalogEntry(
                    oldName: originalName,
                    newName: newName,
                    status: status,
                    byteSize: byteSize,
                    hasInfo: hasInfo,
                    tags: parsed.tags,
                    summary: parsed.summary
                )
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }

        let sortID: Int64
        if hasCatalog, let catalogBook = try bookInfo(for: newName) {
            sortID = catalogBook.id
        } else {
            sortID = bookID
        }

        return Book(
            id: sortID,
            name: newName,
            status: status,
            byteSize: byteSize,
            hasInfo: hasInfo,
            tags: parsed.tags,
            summary: parsed.summary
        )
    }

    private func renameStateReferences(from oldName: String, to newName: String) throws {
        let updates = [
            "UPDATE OR IGNORE state.favorites SET book_name = ? WHERE book_name = ?",
            "UPDATE OR IGNORE state.recent SET book_name = ? WHERE book_name = ?",
            "UPDATE OR IGNORE state.book_status SET book_name = ? WHERE book_name = ?",
            "UPDATE OR IGNORE state.deleted_books SET book_name = ? WHERE book_name = ?",
        ]
        for sql in updates {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            bind(newName, to: statement, at: 1)
            bind(oldName, to: statement, at: 2)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
        }
    }

    private func updateSearchIndexes(rowID: Int64, oldName: String, oldContent: String, newName: String, newContent: String) throws {
        let deleteFTS = try prepare("INSERT INTO library.books_fts(books_fts, rowid, name, content) VALUES('delete', ?, ?, ?)")
        defer { sqlite3_finalize(deleteFTS) }
        bind(rowID, to: deleteFTS, at: 1)
        bind(oldName, to: deleteFTS, at: 2)
        bind(oldContent, to: deleteFTS, at: 3)
        guard sqlite3_step(deleteFTS) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

        let insertFTS = try prepare("INSERT INTO library.books_fts(rowid, name, content) VALUES (?, ?, ?)")
        defer { sqlite3_finalize(insertFTS) }
        bind(rowID, to: insertFTS, at: 1)
        bind(newName, to: insertFTS, at: 2)
        bind(newContent, to: insertFTS, at: 3)
        guard sqlite3_step(insertFTS) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

        guard hasBigramFTS else { return }
        let oldBigrams = Self.bigramDocument(oldContent)
        if !oldBigrams.isEmpty {
            let deleteBigram = try prepare("INSERT INTO library.books_bigram_fts(books_bigram_fts, rowid, grams) VALUES('delete', ?, ?)")
            defer { sqlite3_finalize(deleteBigram) }
            bind(rowID, to: deleteBigram, at: 1)
            bind(oldBigrams, to: deleteBigram, at: 2)
            guard sqlite3_step(deleteBigram) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
        }
        let newBigrams = Self.bigramDocument(newContent)
        if !newBigrams.isEmpty {
            let insertBigram = try prepare("INSERT INTO library.books_bigram_fts(rowid, grams) VALUES (?, ?)")
            defer { sqlite3_finalize(insertBigram) }
            bind(rowID, to: insertBigram, at: 1)
            bind(newBigrams, to: insertBigram, at: 2)
            guard sqlite3_step(insertBigram) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
        }
    }

    private func updateCatalogEntry(
        oldName: String,
        newName: String,
        status: BookStatus,
        byteSize: Int64,
        hasInfo: Bool,
        tags: String,
        summary: String
    ) throws {
        let update = try prepare("""
            UPDATE state.book_catalog
            SET name = ?, status = ?, byte_size = ?, has_info = ?, tags = ?, summary = ?
            WHERE name = ?
        """)
        defer { sqlite3_finalize(update) }
        bind(newName, to: update, at: 1)
        bind(status.rawValue, to: update, at: 2)
        bind(byteSize, to: update, at: 3)
        bind(hasInfo ? 1 : 0, to: update, at: 4)
        bind(tags, to: update, at: 5)
        bind(summary, to: update, at: 6)
        bind(oldName, to: update, at: 7)
        guard sqlite3_step(update) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
        if oldName != newName {
            try moveCatalogEntry(named: newName)
        }
    }

    private func moveCatalogEntry(named targetName: String) throws {
        let currentStatement = try prepare("SELECT sort_order FROM state.book_catalog WHERE name = ? LIMIT 1")
        defer { sqlite3_finalize(currentStatement) }
        bind(targetName, to: currentStatement, at: 1)
        guard sqlite3_step(currentStatement) == SQLITE_ROW else { throw DatabaseError.message("catalog entry not found") }
        let currentOrder = columnInt(currentStatement, 0)

        let rows = try prepare("SELECT name FROM state.book_catalog WHERE name != ? ORDER BY sort_order ASC")
        defer { sqlite3_finalize(rows) }
        var names: [String] = []
        bind(targetName, to: rows, at: 1)
        while sqlite3_step(rows) == SQLITE_ROW {
            names.append(columnText(rows, 0))
        }
        let insertionIndex = names.firstIndex { existingName in
            BookOrdering.compareNames(targetName, existingName) == .orderedAscending
        } ?? names.count
        let newOrder = Int64(insertionIndex + 1)
        guard newOrder != currentOrder else { return }

        let park = try prepare("UPDATE state.book_catalog SET sort_order = 0 WHERE name = ?")
        defer { sqlite3_finalize(park) }
        bind(targetName, to: park, at: 1)
        guard sqlite3_step(park) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

        if newOrder < currentOrder {
            try exec("""
                UPDATE state.book_catalog
                SET sort_order = sort_order + 1
                WHERE sort_order >= \(newOrder) AND sort_order < \(currentOrder)
            """)
        } else {
            try exec("""
                UPDATE state.book_catalog
                SET sort_order = sort_order - 1
                WHERE sort_order > \(currentOrder) AND sort_order <= \(newOrder)
            """)
        }

        let place = try prepare("UPDATE state.book_catalog SET sort_order = ? WHERE name = ?")
        defer { sqlite3_finalize(place) }
        bind(newOrder, to: place, at: 1)
        bind(targetName, to: place, at: 2)
        guard sqlite3_step(place) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
    }

    private static func extractBookInfo(from content: String) -> (tags: String, summary: String) {
        let prefix = String(content.prefix(1200))
        var tags = ""
        var summary = ""
        for line in prefix.components(separatedBy: .newlines).prefix(8) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("【标签】") {
                tags = String(trimmed.dropFirst("【标签】".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("【简介】") {
                summary = String(trimmed.dropFirst("【简介】".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return (tags, summary)
    }

    private static func bigramDocument(_ text: String) -> String {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }
        guard normalized.count >= 2 else { return "" }
        let characters = Array(normalized)
        var seen = Set<String>()
        var tokens: [String] = []
        for index in 0..<(characters.count - 1) {
            let gram = String(characters[index...index + 1])
            if seen.insert(gram).inserted {
                tokens.append(gram)
            }
        }
        return tokens.joined(separator: " ")
    }

    func favorites() throws -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("""
            SELECT favorites.book_name
            FROM state.favorites AS favorites
            WHERE NOT EXISTS (SELECT 1 FROM state.deleted_books WHERE book_name = favorites.book_name)
        """)
        defer { sqlite3_finalize(statement) }
        var values = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            values.insert(columnText(statement, 0))
        }
        return values
    }

    func recent() throws -> [RecentBook] {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("""
            SELECT recent.book_name, recent.timestamp_ms
            FROM state.recent AS recent
            WHERE NOT EXISTS (SELECT 1 FROM state.deleted_books WHERE book_name = recent.book_name)
            ORDER BY recent.timestamp_ms DESC
        """)
        defer { sqlite3_finalize(statement) }
        var values: [RecentBook] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(RecentBook(name: columnText(statement, 0), timestamp: columnInt(statement, 1)))
        }
        return values
    }

    func preferences() throws -> [String: String] {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("SELECT key, value FROM state.preferences")
        defer { sqlite3_finalize(statement) }

        var values: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            values[columnText(statement, 0)] = columnText(statement, 1)
        }
        return values
    }

    func setPreference(_ key: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("INSERT OR REPLACE INTO state.preferences(key, value) VALUES (?, ?)")
        defer { sqlite3_finalize(statement) }
        bind(key, to: statement, at: 1)
        bind(value, to: statement, at: 2)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
    }

    func setFavorite(_ name: String, enabled: Bool) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = enabled
            ? "INSERT OR IGNORE INTO state.favorites(book_name) VALUES (?)"
            : "DELETE FROM state.favorites WHERE book_name = ?"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
    }

    func replaceRecent(_ recent: [RecentBook]) throws {
        lock.lock()
        defer { lock.unlock() }

        try exec("BEGIN IMMEDIATE")
        do {
            try exec("DELETE FROM state.recent")
            let statement = try prepare("INSERT INTO state.recent(book_name, timestamp_ms) VALUES (?, ?)")
            defer { sqlite3_finalize(statement) }
            for item in recent {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bind(item.name, to: statement, at: 1)
                bind(item.timestamp, to: statement, at: 2)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func move(_ name: String, to status: BookStatus) throws {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("INSERT OR REPLACE INTO state.book_status(book_name, status) VALUES (?, ?)")
        defer { sqlite3_finalize(statement) }
        bind(name, to: statement, at: 1)
        bind(status.rawValue, to: statement, at: 2)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
    }

    func moveToTrash(_ name: String) throws {
        lock.lock()
        defer { lock.unlock() }

        try exec("BEGIN IMMEDIATE")
        do {
            let statusStatement = try prepare("INSERT OR REPLACE INTO state.book_status(book_name, status) VALUES (?, 'deleted')")
            defer { sqlite3_finalize(statusStatement) }
            bind(name, to: statusStatement, at: 1)
            guard sqlite3_step(statusStatement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            let favoriteStatement = try prepare("DELETE FROM state.favorites WHERE book_name = ?")
            defer { sqlite3_finalize(favoriteStatement) }
            bind(name, to: favoriteStatement, at: 1)
            guard sqlite3_step(favoriteStatement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            let recentStatement = try prepare("DELETE FROM state.recent WHERE book_name = ?")
            defer { sqlite3_finalize(recentStatement) }
            bind(name, to: recentStatement, at: 1)
            guard sqlite3_step(recentStatement) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func deletePermanently(_ name: String) throws {
        lock.lock()
        defer { lock.unlock() }

        try exec("BEGIN IMMEDIATE")
        do {
            try exec("INSERT OR IGNORE INTO state.deleted_books(book_name) VALUES ('\(Self.sqlLiteral(name))')")
            try exec("DELETE FROM state.book_status WHERE book_name = '\(Self.sqlLiteral(name))'")
            try exec("DELETE FROM state.favorites WHERE book_name = '\(Self.sqlLiteral(name))'")
            try exec("DELETE FROM state.recent WHERE book_name = '\(Self.sqlLiteral(name))'")
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func search(
        query: String,
        mode: String,
        limit: Int,
        isCancelled: @escaping () -> Bool = { false },
        progress: ((SearchProgress) -> Void)? = nil,
        onResult: ((SearchResult) -> Void)? = nil
    ) throws -> [SearchResult] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        try Self.checkCancellation(isCancelled)

        lock.lock()
        defer { lock.unlock() }

        try Self.checkCancellation(isCancelled)
        let cappedLimit = limit == 0 ? Int.max : limit
        let groups = SearchText.termGroups(in: cleaned)
        guard !groups.isEmpty else { return [] }

        if mode == "filename" {
            return try searchFilenames(groups: groups, limit: cappedLimit, isCancelled: isCancelled, progress: progress, onResult: onResult)
        }

        return try searchContent(groups: groups, limit: cappedLimit, isCancelled: isCancelled, progress: progress, onResult: onResult)
    }

    func searchPresets() throws -> [SearchPreset] {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("""
            SELECT query, updated_at
            FROM state.search_presets
            ORDER BY updated_at DESC, query COLLATE NOCASE ASC
        """)
        defer { sqlite3_finalize(statement) }
        var values: [SearchPreset] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(SearchPreset(query: columnText(statement, 0), updatedAt: columnInt(statement, 1)))
        }
        return values
    }

    func searchPresetResults(query: String) throws -> [SearchResult] {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("""
            SELECT entries.book_name, entries.snippet
            FROM state.search_preset_entries AS entries
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = entries.book_name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = entries.book_name
            LEFT JOIN state.book_catalog AS catalog ON catalog.name = entries.book_name
            WHERE entries.query = ?
              AND state_deleted.book_name IS NULL
              AND COALESCE(state_status.status, catalog.status, 'active') = 'active'
            ORDER BY entries.sort_order ASC
        """)
        defer { sqlite3_finalize(statement) }
        bind(query, to: statement, at: 1)
        var results: [SearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(SearchResult(bookName: columnText(statement, 0), snippet: columnText(statement, 1)))
        }
        return results
    }

    func searchContent(
        query: String,
        candidateNames rawCandidateNames: [String],
        limit: Int,
        isCancelled: @escaping () -> Bool = { false },
        progress: ((SearchProgress) -> Void)? = nil,
        onResult: ((SearchResult) -> Void)? = nil
    ) throws -> [SearchResult] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateNames = Array(Set(rawCandidateNames))
        guard !cleaned.isEmpty, !candidateNames.isEmpty else { return [] }
        let cappedLimit = limit == 0 ? Int.max : limit
        let groups = SearchText.termGroups(in: cleaned)
        guard !groups.isEmpty else { return [] }

        lock.lock()
        defer { lock.unlock() }
        try Self.checkCancellation(isCancelled)

        try exec("DROP TABLE IF EXISTS temp.search_candidates")
        try exec("CREATE TEMP TABLE search_candidates(name TEXT PRIMARY KEY NOT NULL)")
        do {
            try exec("BEGIN IMMEDIATE")
            let insert = try prepare("INSERT OR IGNORE INTO temp.search_candidates(name) VALUES (?)")
            defer { sqlite3_finalize(insert) }
            for name in candidateNames {
                try Self.checkCancellation(isCancelled)
                sqlite3_reset(insert)
                sqlite3_clear_bindings(insert)
                bind(name, to: insert, at: 1)
                guard sqlite3_step(insert) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            try? exec("DROP TABLE IF EXISTS temp.search_candidates")
            throw error
        }

        let snippetWindows = Self.snippetWindowExpressions(for: groups)
        let snippetSelectSQL = snippetWindows.expressions.isEmpty ? ", books.content" : ", \(snippetWindows.expressions.joined(separator: ", "))"
        let whereSQL = Self.containsWhereClause(for: groups, column: "books.content")
        let statement = try prepare("""
            SELECT books.name\(snippetSelectSQL)
            FROM temp.search_candidates AS candidates
            JOIN library.books AS books ON books.name = candidates.name
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE COALESCE(state_status.status, books.status) = 'active'
              AND state_deleted.book_name IS NULL
              AND \(whereSQL)
        """)
        defer {
            sqlite3_finalize(statement)
            try? exec("DROP TABLE IF EXISTS temp.search_candidates")
        }
        var bindIndex: Int32 = 1
        for value in snippetWindows.bindValues {
            bind(value, to: statement, at: bindIndex)
            bindIndex += 1
        }
        _ = bindGroups(groups, to: statement, startingAt: bindIndex)

        var searched = 0
        var results: [SearchResult] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW, results.count < cappedLimit {
            try Self.checkCancellation(isCancelled)
            searched += 1
            let name = columnText(statement, 0)
            let snippetSource: String
            if snippetWindows.expressions.isEmpty {
                let content = columnText(statement, 1)
                let repaired = SearchText.repairMojibakeIfNeeded(content)
                guard Self.matches(content, groups: groups, repairedText: repaired, filenameMode: false) else {
                    step = sqlite3_step(statement)
                    continue
                }
                snippetSource = repaired
            } else {
                let fragments = (0..<groups.count)
                    .map { columnText(statement, Int32($0 + 1)) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
                snippetSource = SearchText.repairMojibakeIfNeeded(fragments)
            }
            let result = SearchResult(bookName: name, snippet: Self.snippet(in: snippetSource, terms: groups.map(\.term)))
            results.append(result)
            onResult?(result)
            if searched % 100 == 0 {
                progress?(SearchProgress(total: candidateNames.count, searched: searched, matched: results.count, unit: "缓存候选"))
            }
            step = sqlite3_step(statement)
        }
        if results.count < cappedLimit {
            try Self.checkSearchStep(step, isCancelled: isCancelled)
        }
        progress?(SearchProgress(total: candidateNames.count, searched: min(searched, candidateNames.count), matched: results.count, unit: "缓存候选"))
        return results
    }

    func saveSearchPreset(query: String, results: [SearchResult]) throws {
        lock.lock()
        defer { lock.unlock() }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        try exec("BEGIN IMMEDIATE")
        do {
            let upsertPreset = try prepare("""
                INSERT INTO state.search_presets(query, updated_at)
                VALUES (?, ?)
                ON CONFLICT(query) DO UPDATE SET updated_at = excluded.updated_at
            """)
            defer { sqlite3_finalize(upsertPreset) }
            bind(query, to: upsertPreset, at: 1)
            bind(timestamp, to: upsertPreset, at: 2)
            guard sqlite3_step(upsertPreset) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            let deleteEntries = try prepare("DELETE FROM state.search_preset_entries WHERE query = ?")
            defer { sqlite3_finalize(deleteEntries) }
            bind(query, to: deleteEntries, at: 1)
            guard sqlite3_step(deleteEntries) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            let insertEntry = try prepare("""
                INSERT INTO state.search_preset_entries(query, book_name, snippet, sort_order)
                VALUES (?, ?, ?, ?)
            """)
            defer { sqlite3_finalize(insertEntry) }
            for (index, result) in results.enumerated() {
                sqlite3_reset(insertEntry)
                sqlite3_clear_bindings(insertEntry)
                bind(query, to: insertEntry, at: 1)
                bind(result.bookName, to: insertEntry, at: 2)
                bind(result.snippet, to: insertEntry, at: 3)
                bind(Int64(index + 1), to: insertEntry, at: 4)
                guard sqlite3_step(insertEntry) == SQLITE_DONE else { throw DatabaseError.message(lastError) }
            }

            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func searchCandidateNames(
        query: String,
        limit: Int,
        isCancelled: @escaping () -> Bool = { false },
        progress: ((SearchProgress) -> Void)? = nil
    ) throws -> [String] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        let cappedLimit = limit == 0 ? Int.max : limit
        let groups = SearchText.termGroups(in: cleaned)
        guard !groups.isEmpty else { return [] }

        lock.lock()
        defer { lock.unlock() }

        let trigramGroups = groups.filter { $0.term.count >= 3 }
        let candidateBigramGroups = hasBigramFTS ? groups.filter { $0.term.count == 2 } : []
        let trigramQuery = Self.ftsQuery(for: trigramGroups)
        let bigramQuery = Self.bigramQuery(for: candidateBigramGroups)

        guard trigramQuery != nil || bigramQuery != nil else {
            return try scanCandidateNames(groups: groups, limit: cappedLimit, isCancelled: isCancelled, progress: progress)
        }

        var joins: [String] = []
        var whereParts = [
            "COALESCE(state_status.status, books.status) = 'active'",
            "state_deleted.book_name IS NULL",
        ]
        if trigramQuery != nil {
            joins.append("JOIN library.books_fts AS books_fts ON books_fts.rowid = books.id")
            whereParts.append("books_fts MATCH ?")
        }
        if bigramQuery != nil {
            joins.append("JOIN library.books_bigram_fts AS books_bigram_fts ON books_bigram_fts.rowid = books.id")
            whereParts.append("books_bigram_fts MATCH ?")
        }
        whereParts.append(Self.containsWhereClause(for: groups, column: "books.content"))
        let joinSQL = joins.joined(separator: "\n")
        let whereSQL = whereParts.joined(separator: "\n  AND ")
        let statement = try prepare("""
            SELECT books.name
            FROM library.books AS books
            \(joinSQL)
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE \(whereSQL)
        """)
        defer { sqlite3_finalize(statement) }
        var bindIndex: Int32 = 1
        if let trigramQuery {
            bind(trigramQuery, to: statement, at: bindIndex)
            bindIndex += 1
        }
        if let bigramQuery {
            bind(bigramQuery, to: statement, at: bindIndex)
            bindIndex += 1
        }
        _ = bindGroups(groups, to: statement, startingAt: bindIndex)

        var searched = 0
        var names: [String] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW, names.count < cappedLimit {
            try Self.checkCancellation(isCancelled)
            searched += 1
            names.append(columnText(statement, 0))
            if searched % 1000 == 0 {
                progress?(SearchProgress(total: 0, searched: searched, matched: names.count, unit: "候选"))
            }
            step = sqlite3_step(statement)
        }
        if names.count < cappedLimit {
            try Self.checkSearchStep(step, isCancelled: isCancelled)
        }
        progress?(SearchProgress(total: searched, searched: searched, matched: names.count, unit: "候选"))
        return names
    }

    private func scanCandidateNames(
        groups: [SearchTermGroup],
        limit: Int,
        isCancelled: @escaping () -> Bool,
        progress: ((SearchProgress) -> Void)?
    ) throws -> [String] {
        let whereSQL = Self.containsWhereClause(for: groups, column: "books.content")
        let statement = try prepare("""
            SELECT books.name
            FROM library.books AS books
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE COALESCE(state_status.status, books.status) = 'active'
              AND state_deleted.book_name IS NULL
              AND \(whereSQL)
        """)
        _ = bindGroups(groups, to: statement, startingAt: 1)
        defer { sqlite3_finalize(statement) }

        var searched = 0
        var names: [String] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW, names.count < limit {
            try Self.checkCancellation(isCancelled)
            searched += 1
            names.append(columnText(statement, 0))
            if searched % 1000 == 0 {
                progress?(SearchProgress(total: 0, searched: searched, matched: names.count, unit: "本"))
            }
            step = sqlite3_step(statement)
        }
        if names.count < limit {
            try Self.checkSearchStep(step, isCancelled: isCancelled)
        }
        progress?(SearchProgress(total: searched, searched: searched, matched: names.count, unit: "本"))
        return names
    }

    func deleteSearchPreset(query: String) throws {
        lock.lock()
        defer { lock.unlock() }

        try exec("BEGIN IMMEDIATE")
        do {
            let deleteEntries = try prepare("DELETE FROM state.search_preset_entries WHERE query = ?")
            defer { sqlite3_finalize(deleteEntries) }
            bind(query, to: deleteEntries, at: 1)
            guard sqlite3_step(deleteEntries) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            let deletePreset = try prepare("DELETE FROM state.search_presets WHERE query = ?")
            defer { sqlite3_finalize(deletePreset) }
            bind(query, to: deletePreset, at: 1)
            guard sqlite3_step(deletePreset) == SQLITE_DONE else { throw DatabaseError.message(lastError) }

            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    private func searchFilenames(
        groups: [SearchTermGroup],
        limit: Int,
        isCancelled: @escaping () -> Bool,
        progress: ((SearchProgress) -> Void)?,
        onResult: ((SearchResult) -> Void)?
    ) throws -> [SearchResult] {
        try Self.checkCancellation(isCancelled)
        let tableSQL = hasCatalog ? "state.book_catalog AS catalog" : "library.books AS catalog"
        let whereSQL = Self.containsWhereClause(for: groups, column: "catalog.name")
        let orderSQL = hasCatalog ? "catalog.sort_order ASC" : "catalog.name COLLATE NOCASE"
        let statement = try prepare("""
                SELECT catalog.name, ''
                FROM \(tableSQL)
                LEFT JOIN state.book_status AS state_status ON state_status.book_name = catalog.name
                LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = catalog.name
                WHERE COALESCE(state_status.status, catalog.status) = 'active'
                  AND state_deleted.book_name IS NULL
                  AND \(whereSQL)
                ORDER BY \(orderSQL)
                LIMIT ?
            """)
        defer { sqlite3_finalize(statement) }
        let nextIndex = bindGroups(groups, to: statement, startingAt: 1)
        bind(Int64(limit), to: statement, at: nextIndex)

        var searched = 0
        var results: [SearchResult] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW {
            try Self.checkCancellation(isCancelled)
            searched += 1
            let name = columnText(statement, 0)
            let result = SearchResult(bookName: name, snippet: "")
            results.append(result)
            onResult?(result)
            if searched % 200 == 0 {
                progress?(SearchProgress(total: searched, searched: searched, matched: results.count, unit: "本"))
            }
            step = sqlite3_step(statement)
        }
        try Self.checkSearchStep(step, isCancelled: isCancelled)
        progress?(SearchProgress(total: searched, searched: searched, matched: results.count, unit: "本"))
        return results
    }

    private func searchContent(
        groups: [SearchTermGroup],
        limit: Int,
        isCancelled: @escaping () -> Bool,
        progress: ((SearchProgress) -> Void)?,
        onResult: ((SearchResult) -> Void)?
    ) throws -> [SearchResult] {
        try Self.checkCancellation(isCancelled)
        let trigramGroups = groups.filter { $0.term.count >= 3 }
        let candidateBigramGroups = hasBigramFTS ? groups.filter { $0.term.count == 2 } : []
        let trigramQuery = Self.ftsQuery(for: trigramGroups)
        let bigramQuery = Self.bigramQuery(for: candidateBigramGroups)
        guard trigramQuery != nil || bigramQuery != nil else {
            return try scanContent(groups: groups, limit: limit, isCancelled: isCancelled, progress: progress, onResult: onResult)
        }

        var joins: [String] = []
        var whereParts = [
            "COALESCE(state_status.status, books.status) = 'active'",
            "state_deleted.book_name IS NULL",
        ]
        if trigramQuery != nil {
            joins.append("JOIN library.books_fts AS books_fts ON books_fts.rowid = books.id")
            whereParts.append("books_fts MATCH ?")
        }
        if bigramQuery != nil {
            joins.append("JOIN library.books_bigram_fts AS books_bigram_fts ON books_bigram_fts.rowid = books.id")
            whereParts.append("books_bigram_fts MATCH ?")
        }
        whereParts.append(Self.containsWhereClause(for: groups, column: "books.content"))
        let joinSQL = joins.joined(separator: "\n")
        let whereSQL = whereParts.joined(separator: "\n  AND ")
        try Self.checkCancellation(isCancelled)

        let snippetWindows = Self.snippetWindowExpressions(for: groups)
        let snippetSelectSQL = snippetWindows.expressions.isEmpty ? ", books.content" : ", \(snippetWindows.expressions.joined(separator: ", "))"
        let statement = try prepare("""
            SELECT books.name\(snippetSelectSQL)
            FROM library.books AS books
            \(joinSQL)
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE \(whereSQL)
            LIMIT ?
        """)
        defer { sqlite3_finalize(statement) }
        var bindIndex: Int32 = 1
        for value in snippetWindows.bindValues {
            bind(value, to: statement, at: bindIndex)
            bindIndex += 1
        }
        if let trigramQuery {
            bind(trigramQuery, to: statement, at: bindIndex)
            bindIndex += 1
        }
        if let bigramQuery {
            bind(bigramQuery, to: statement, at: bindIndex)
            bindIndex += 1
        }
        bindIndex = bindGroups(groups, to: statement, startingAt: bindIndex)
        bind(Int64(limit), to: statement, at: bindIndex)

        var searched = 0
        var results: [SearchResult] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW, results.count < limit {
            try Self.checkCancellation(isCancelled)
            searched += 1
            let name = columnText(statement, 0)
            let snippetSource: String
            if snippetWindows.expressions.isEmpty {
                let content = columnText(statement, 1)
                let repaired = SearchText.repairMojibakeIfNeeded(content)
                guard Self.matches(content, groups: groups, repairedText: repaired, filenameMode: false) else {
                    step = sqlite3_step(statement)
                    continue
                }
                snippetSource = repaired
            } else {
                let fragments = (0..<groups.count)
                    .map { columnText(statement, Int32($0 + 1)) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
                snippetSource = SearchText.repairMojibakeIfNeeded(fragments)
            }
            let result = SearchResult(bookName: name, snippet: Self.snippet(in: snippetSource, terms: groups.map(\.term)))
            results.append(result)
            onResult?(result)
            if searched % 500 == 0 {
                progress?(SearchProgress(total: 0, searched: searched, matched: results.count, unit: "候选"))
            }
            step = sqlite3_step(statement)
        }
        if results.count < limit {
            try Self.checkSearchStep(step, isCancelled: isCancelled)
        }
        progress?(SearchProgress(total: searched, searched: searched, matched: results.count, unit: "候选"))
        return results
    }

    private func scanContent(
        groups: [SearchTermGroup],
        limit: Int,
        isCancelled: @escaping () -> Bool,
        progress: ((SearchProgress) -> Void)?,
        onResult: ((SearchResult) -> Void)?
    ) throws -> [SearchResult] {
        try Self.checkCancellation(isCancelled)
        let whereSQL = Self.containsWhereClause(for: groups, column: "books.content")
        let statement = try prepare("""
            SELECT books.name, books.content
            FROM library.books AS books
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE COALESCE(state_status.status, books.status) = 'active'
              AND state_deleted.book_name IS NULL
              AND \(whereSQL)
        """)
        _ = bindGroups(groups, to: statement, startingAt: 1)
        defer { sqlite3_finalize(statement) }

        var searched = 0
        var results: [SearchResult] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW, results.count < limit {
            try Self.checkCancellation(isCancelled)
            searched += 1
            let name = columnText(statement, 0)
            let content = columnText(statement, 1)
            let repaired = SearchText.repairMojibakeIfNeeded(content)
            guard Self.matches(content, groups: groups, repairedText: repaired, filenameMode: false) else {
                step = sqlite3_step(statement)
                continue
            }
            let result = SearchResult(bookName: name, snippet: Self.snippet(in: repaired, terms: groups.map(\.term)))
            results.append(result)
            onResult?(result)
            if searched % 100 == 0 {
                progress?(SearchProgress(total: 0, searched: searched, matched: results.count, unit: "匹配"))
            }
            step = sqlite3_step(statement)
        }
        if results.count < limit {
            try Self.checkSearchStep(step, isCancelled: isCancelled)
        }
        progress?(SearchProgress(total: searched, searched: searched, matched: results.count, unit: "匹配"))
        return results
    }

    func searchSnippet(bookName: String, query: String) throws -> String {
        let groups = SearchText.termGroups(in: query)
        guard !groups.isEmpty else { return "" }
        guard let content = try content(for: bookName) else { return "" }
        let repaired = SearchText.repairMojibakeIfNeeded(content)
        guard Self.matches(content, groups: groups, repairedText: repaired, filenameMode: false) else { return "" }
        return Self.snippet(in: repaired, terms: groups.map(\.term))
    }

    private func activeBookCount() throws -> Int {
        let sql = hasCatalog
            ? """
            SELECT COUNT(*)
            FROM state.book_catalog AS catalog
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = catalog.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = catalog.name
            WHERE COALESCE(state_status.status, catalog.status) = 'active'
              AND state_deleted.book_name IS NULL
            """
            : """
            SELECT COUNT(*)
            FROM library.books AS books
            LEFT JOIN state.book_status AS state_status ON state_status.book_name = books.name
            LEFT JOIN state.deleted_books AS state_deleted ON state_deleted.book_name = books.name
            WHERE COALESCE(state_status.status, books.status) = 'active'
              AND state_deleted.book_name IS NULL
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        return try count(from: statement)
    }

    private func count(from statement: OpaquePointer?) throws -> Int {
        guard sqlite3_step(statement) == SQLITE_ROW else { throw DatabaseError.message(lastError) }
        return Int(columnInt(statement, 0))
    }

    @discardableResult
    private func bindGroups(_ groups: [SearchTermGroup], to statement: OpaquePointer?, startingAt start: Int32) -> Int32 {
        var index = start
        for group in groups {
            for alternative in group.alternatives {
                bind(alternative, to: statement, at: index)
                index += 1
            }
        }
        return index
    }

    private static func containsWhereClause(for groups: [SearchTermGroup], column: String) -> String {
        groups.map { group in
            let clauses = group.alternatives.map { _ in "instr(\(column), ?) > 0" }.joined(separator: " OR ")
            return "(\(clauses))"
        }.joined(separator: " AND ")
    }

    private static func snippetWindowExpressions(for groups: [SearchTermGroup]) -> (expressions: [String], bindValues: [String]) {
        guard !groups.isEmpty else { return ([], []) }
        var expressions: [String] = []
        var bindValues: [String] = []

        for group in groups {
            var cases: [String] = []
            for alternative in group.alternatives {
                cases.append("WHEN instr(books.content, ?) > 0 THEN substr(books.content, max(instr(books.content, ?) - 90, 1), 240)")
                bindValues.append(alternative)
                bindValues.append(alternative)
            }
            expressions.append("CASE \(cases.joined(separator: " ")) ELSE '' END")
        }

        return (expressions, bindValues)
    }

    private static func checkCancellation(_ isCancelled: () -> Bool) throws {
        if isCancelled() {
            throw SearchCancellation.cancelled
        }
    }

    private static func checkSearchStep(_ step: Int32, isCancelled: () -> Bool) throws {
        if step == SQLITE_DONE {
            return
        }
        if isCancelled() || step == SQLITE_INTERRUPT {
            throw SearchCancellation.cancelled
        }
        throw DatabaseError.message("SQLite search failed with code \(step)")
    }

    private static func matches(
        _ rawText: String,
        groups: [SearchTermGroup],
        repairedText: String,
        filenameMode: Bool
    ) -> Bool {
        groups.allSatisfy { group in
            if repairedText.range(of: group.term, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return true
            }
            guard !filenameMode else { return false }
            return group.alternatives.contains { alternative in
                rawText.range(of: alternative, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    private static func snippet(in content: String, terms: [String]) -> String {
        let targetLength = 28
        var pendingTerms = terms
        var selected: [Int: String] = [:]
        var firstLine: String?
        var lineIndex = 0

        func consume(_ rawLine: String) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return }
            var chunk = ""
            for character in line {
                chunk.append(character)
                if chunk.count >= targetLength {
                    inspect(chunk)
                    chunk = ""
                }
            }
            if !chunk.isEmpty {
                inspect(chunk)
            }
        }

        func inspect(_ line: String) {
            if firstLine == nil {
                firstLine = line
            }
            let matchedTerms = pendingTerms.filter { term in
                line.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            if !matchedTerms.isEmpty {
                selected[lineIndex] = line
                pendingTerms.removeAll { term in
                    matchedTerms.contains { $0.caseInsensitiveCompare(term) == .orderedSame }
                }
            }
            lineIndex += 1
        }

        content.enumerateLines { rawLine, stop in
            consume(rawLine)
            if pendingTerms.isEmpty {
                stop = true
            }
        }

        guard !selected.isEmpty else { return firstLine ?? "" }
        let sorted = selected.keys.sorted()
        var blocks: [[Int]] = []
        for index in sorted {
            if let lastBlock = blocks.indices.last, let last = blocks[lastBlock].last, index == last + 1 {
                blocks[lastBlock].append(index)
            } else {
                blocks.append([index])
            }
        }

        return blocks.map { block in
            var text = block.compactMap { selected[$0] }.joined(separator: "\n")
            if let first = block.first, first > 0 {
                text = "..." + text
            }
            if pendingTerms.isEmpty || (block.last ?? 0) < lineIndex - 1 {
                text += "..."
            }
            return text
        }.joined(separator: "\n")
    }

    private static func displayLines(in content: String) -> [String] {
        let targetLength = 28
        var lines: [String] = []
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            var chunk = ""
            for character in line {
                chunk.append(character)
                if chunk.count >= targetLength {
                    lines.append(chunk)
                    chunk = ""
                }
            }
            if !chunk.isEmpty {
                lines.append(chunk)
            }
        }
        return lines
    }

    private static func ftsQuery(for groups: [SearchTermGroup]) -> String? {
        ngramQuery(for: groups, width: 3)
    }

    private static func bigramQuery(for groups: [SearchTermGroup]) -> String? {
        ngramQuery(for: groups, width: 2)
    }

    private static func ngramQuery(for groups: [SearchTermGroup], width: Int) -> String? {
        guard !groups.isEmpty else { return nil }
        let groupQueries = groups.compactMap { group -> String? in
            let alternatives = group.alternatives.compactMap { alternative -> String? in
                let tokens = ngrams(in: alternative, width: width)
                guard !tokens.isEmpty, tokens.allSatisfy(isFTSBareword) else { return nil }
                return tokens.joined(separator: " AND ")
            }
            guard !alternatives.isEmpty else { return nil }
            return alternatives.count == 1 ? alternatives[0] : "(\(alternatives.joined(separator: " OR ")))"
        }
        guard groupQueries.count == groups.count else { return nil }
        return groupQueries.joined(separator: " AND ")
    }

    private static func ngrams(in value: String, width: Int) -> [String] {
        let characters = Array(value)
        guard width > 0, characters.count >= width else { return [] }
        return (0...(characters.count - width)).map { index in
            String(characters[index..<(index + width)])
        }
    }

    private static func isFTSBareword(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            if scalar.value >= 128 {
                return true
            }
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
                return true
            }
            return false
        }
    }

    private static func sqlLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}

enum DatabaseError: Error {
    case message(String)
}

#if false
@MainActor
final class ReaderStore: ObservableObject {
    private var database: SQLiteStore?
    private let searchLock = NSLock()
    private var activeSearchToken: SearchCancellationToken?

    @Published var isReady = false
    @Published var startupError: String?
    @Published var books: [Book] = []
    @Published var trashBooks: [Book] = []
    @Published var favorites = Set<String>()
    @Published var recent: [RecentBook] = []
    @Published var fontSize = 18
    @Published var recentLimit = 20
    @Published var searchMode = "fulltext"
    @Published var searchResultLimit = 50
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var searchLoading = false
    @Published var searchResults: [SearchResult] = []

    init() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let database = try SQLiteStore()
                let snapshot = try Self.makeSnapshot(database: database)
                DispatchQueue.main.async {
                    self.database = database
                    self.apply(snapshot)
                    self.isReady = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.startupError = "书库初始化失败：\(error)"
                }
            }
        }
    }

    private struct Snapshot {
        let books: [Book]
        let trashBooks: [Book]
        let favorites: Set<String>
        let recent: [RecentBook]
        let preferences: [String: String]
    }

    nonisolated private static func makeSnapshot(database: SQLiteStore) throws -> Snapshot {
        return Snapshot(
            books: try database.books(status: .active),
            trashBooks: try database.books(status: .deleted),
            favorites: try database.favorites(),
            recent: try database.recent(),
            preferences: try database.preferences()
        )
    }

    private func apply(_ snapshot: Snapshot) {
        books = snapshot.books
        trashBooks = snapshot.trashBooks
        favorites = snapshot.favorites
        recent = snapshot.recent
        fontSize = Int(snapshot.preferences["fontSize"] ?? "") ?? 18
        recentLimit = Int(snapshot.preferences["recentLimit"] ?? "") ?? 20
        searchMode = snapshot.preferences["searchMode"] ?? "fulltext"
        searchResultLimit = Int(snapshot.preferences["searchResultLimit"] ?? "") ?? 50
    }

    var favoriteBooks: [Book] {
        books.filter { favorites.contains($0.name) }
    }

    var activeNames: Set<String> {
        Set(books.map(\.name))
    }

    var trashNames: Set<String> {
        Set(trashBooks.map(\.name))
    }

    func loadState() {
        do {
            guard let database else { return }
            apply(try Self.makeSnapshot(database: database))
        } catch {
            print("loadState failed: \(error)")
        }
    }

    func content(for name: String) -> String {
        guard let database else { return "加载中..." }
        return (try? database.content(for: name)) ?? "文件未找到。"
    }

    func book(named name: String) -> Book? {
        books.first { $0.name == name } ?? trashBooks.first { $0.name == name }
    }

    func toggleFavorite(_ name: String) {
        let enabled = !favorites.contains(name)
        if enabled {
            favorites.insert(name)
        } else {
            favorites.remove(name)
        }
        try? database?.setFavorite(name, enabled: enabled)
    }

    func addToRecent(_ name: String) {
        guard recentLimit != 0 else { return }
        recent.removeAll { $0.name == name }
        recent.insert(RecentBook(name: name, timestamp: Int64(Date().timeIntervalSince1970 * 1000)), at: 0)
        if recent.count > recentLimit {
            recent = Array(recent.prefix(recentLimit))
        }
        try? database?.replaceRecent(recent)
    }

    func removeFromRecent(_ name: String) {
        recent.removeAll { $0.name == name }
        try? database?.replaceRecent(recent)
    }

    func clearRecent() {
        recent = []
        try? database?.replaceRecent(recent)
    }

    func moveToTrash(_ name: String) {
        guard let index = books.firstIndex(where: { $0.name == name }) else { return }
        let book = books.remove(at: index)
        trashBooks.append(Book(
            id: book.id,
            name: book.name,
            status: .deleted,
            hasInfo: book.hasInfo,
            tags: book.tags,
            summary: book.summary
        ))
        try? database?.move(name, to: .deleted)
    }

    func restoreFromTrash(_ name: String) {
        guard let index = trashBooks.firstIndex(where: { $0.name == name }) else { return }
        let book = trashBooks.remove(at: index)
        books.append(Book(
            id: book.id,
            name: book.name,
            status: .active,
            hasInfo: book.hasInfo,
            tags: book.tags,
            summary: book.summary
        ))
        books.sort { $0.id < $1.id }
        try? database?.move(name, to: .active)
    }

    func deletePermanently(_ name: String) {
        trashBooks.removeAll { $0.name == name }
        books.removeAll { $0.name == name }
        favorites.remove(name)
        recent.removeAll { $0.name == name }
        try? database?.deletePermanently(name)
    }

    func setFontSize(_ value: Int) {
        fontSize = min(max(value, 14), 24)
        try? database?.setPreference("fontSize", value: String(fontSize))
    }

    func setRecentLimit(_ value: Int) {
        recentLimit = min(max(value, 0), 200)
        if recent.count > recentLimit {
            recent = Array(recent.prefix(recentLimit))
            try? database?.replaceRecent(recent)
        }
        try? database?.setPreference("recentLimit", value: String(recentLimit))
    }

    func setSearchMode(_ value: String) {
        searchMode = value
        try? database?.setPreference("searchMode", value: value)
    }

    func setSearchResultLimit(_ value: Int) {
        searchResultLimit = value
        try? database?.setPreference("searchResultLimit", value: String(value))
    }

    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        guard let database else { return }
        isSearching = true
        searchLoading = true
        searchResults = []

        let mode = searchMode
        let limit = searchResultLimit
        DispatchQueue.global(qos: .userInitiated).async { [database] in
            let results = (try? database.search(query: query, mode: mode, limit: limit)) ?? []
            DispatchQueue.main.async {
                self.searchResults = results
                self.searchLoading = false
            }
        }
    }

    func exitSearch() {
        isSearching = false
        searchQuery = ""
        searchResults = []
        searchLoading = false
    }

    func exportURL(for name: String) -> URL? {
        let content = content(for: name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(Self.safeExportFilename(for: name)).txt")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func safeExportFilename(for name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>").union(.newlines).union(.controlCharacters)
        let parts = name.unicodeScalars.map { scalar -> Character in
            illegal.contains(scalar) ? "_" : Character(scalar)
        }
        let cleaned = String(parts)
            .replacingOccurrences(of: #"\.{2,}"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
        return cleaned.isEmpty ? "未命名" : String(cleaned.prefix(80))
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ReaderStore
    @State private var path: [Route] = []

    var body: some View {
        Group {
            if store.isReady {
                NavigationStack(path: $path) {
                    HomeView(path: $path)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .recent:
                                RecentView(path: $path)
                            case .favorites:
                                FavoritesView(path: $path)
                            case .settings:
                                SettingsView(path: $path)
                            case .trash:
                                TrashView(path: $path)
                            case .reader(let name):
                                ReaderView(path: $path, bookName: name)
                            }
                        }
                }
            } else {
                StartupView(error: store.startupError)
            }
        }
        .tint(.readerBlue)
    }
}

struct StartupView: View {
    let error: String?

    var body: some View {
        VStack(spacing: 18) {
            if let error {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34))
                    .foregroundColor(.readerOrange)
                Text(error)
                    .font(.system(size: 15))
                    .foregroundColor(.readerText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else {
                ProgressView()
                    .tint(.readerBlue)
                Text("正在初始化书库...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text("首次启动需要准备本地数据库，完成后配置和书库状态会保存在设备上。")
                    .font(.system(size: 13))
                    .foregroundColor(.readerSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.readerBackground.ignoresSafeArea())
    }
}
struct HomeView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]
    @State private var selected = Set<String>()
    @State private var expandedBook: String?
    @State private var deleteTarget: DeleteTarget?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HeaderView(title: "书架") {
                    Button { path.append(.recent) } label: { Image(systemName: "clock") }
                    Button { path.append(.favorites) } label: { Image(systemName: "star") }
                    Button { path.append(.settings) } label: { Image(systemName: "gearshape") }
                }

                SearchBar()

                if store.isSearching {
                    SearchResultsView(path: $path)
                } else {
                    BookListView(
                        books: store.books,
                        icon: "doc.text",
                        selected: $selected,
                        expandedBook: $expandedBook,
                        onOpen: openBook,
                        onDelete: { deleteTarget = .single($0) },
                        showInfo: true
                    )
                }
            }
            .padding(.horizontal, 20)
            .background(Color.readerBackground.ignoresSafeArea())

            if !selected.isEmpty {
                SelectionFooter {
                    FooterAction(title: "收藏", systemImage: "star") {
                        selected.forEach { if !store.favorites.contains($0) { store.toggleFavorite($0) } }
                        selected.removeAll()
                    }
                    FooterAction(title: "删除", systemImage: "trash", tint: .readerRed) {
                        deleteTarget = .multiple(Array(selected))
                    }
                    FooterAction(title: "取消", systemImage: "xmark", tint: .white) {
                        selected.removeAll()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert(item: $deleteTarget) { target in
            Alert(
                title: Text("删除书籍"),
                message: Text(target.message),
                primaryButton: .destructive(Text("删除")) {
                    target.names.forEach(store.moveToTrash)
                    selected.removeAll()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private func openBook(_ name: String) {
        store.addToRecent(name)
        path.append(.reader(name))
    }
}

struct SearchBar: View {
    @EnvironmentObject private var store: ReaderStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.readerSecondary)
            TextField(store.searchMode == "filename" ? "文件名搜索..." : "全文搜索...", text: $store.searchQuery)
                .submitLabel(.search)
                .onSubmit(store.performSearch)
                .foregroundColor(.white)
            if !store.searchQuery.isEmpty {
                Button { store.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.readerSecondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color.readerPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.bottom, 15)
    }
}

struct SearchResultsView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("搜索结果")
                    .font(.system(size: 14))
                    .foregroundColor(.readerSecondary)
                Spacer()
                Button("退出", action: store.exitSearch)
                    .font(.system(size: 14))
            }
            .padding(.bottom, 10)

            if store.searchLoading {
                Spacer()
                Text("搜索中...")
                    .foregroundColor(.readerSecondary)
                Spacer()
            } else if store.searchResults.isEmpty {
                Spacer()
                Text("未找到相关内容")
                    .foregroundColor(.readerSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.searchResults) { result in
                            Button {
                                store.addToRecent(result.bookName)
                                path.append(.reader(result.bookName))
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HighlightedText(text: result.bookName, query: store.searchQuery, fontSize: 15, weight: .semibold)
                                    if !result.snippet.isEmpty {
                                        HighlightedText(text: result.snippet, query: store.searchQuery, fontSize: 13, weight: .regular)
                                            .foregroundStyle(Color.readerText)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.readerPanel)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct HighlightedText: View {
    let text: String
    let query: String
    let fontSize: CGFloat
    let weight: Font.Weight

    var body: some View {
        Text(attributed)
            .font(.system(size: fontSize, weight: weight))
            .foregroundColor(.white)
    }

    private var attributed: AttributedString {
        var value = AttributedString(text)
        guard !query.isEmpty else { return value }
        var searchStart = value.startIndex
        while let range = value[searchStart...].range(of: query, options: [.caseInsensitive]) {
            value[range].foregroundColor = .readerBlue
            value[range].font = .system(size: fontSize, weight: .bold)
            searchStart = range.upperBound
        }
        return value
    }
}

struct BookListView: View {
    let books: [Book]
    let icon: String
    @Binding var selected: Set<String>
    @Binding var expandedBook: String?
    let onOpen: (String) -> Void
    let onDelete: (String) -> Void
    var onRemove: ((String) -> Void)?
    var showInfo = false

    var body: some View {
        if books.isEmpty {
            Spacer()
            Text("暂无书籍")
                .foregroundColor(.readerSecondary)
            Spacer()
        } else {
            List {
                ForEach(books) { book in
                    VStack(spacing: 0) {
                        BookRow(
                            book: book,
                            icon: icon,
                            isSelected: selected.contains(book.name),
                            isSelecting: !selected.isEmpty,
                            isExpanded: expandedBook == book.name,
                            showInfo: showInfo,
                            onToggleInfo: {
                                expandedBook = expandedBook == book.name ? nil : book.name
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selected.isEmpty {
                                onOpen(book.name)
                            } else {
                                toggleSelection(book.name)
                            }
                        }
                        .onLongPressGesture {
                            selected.insert(book.name)
                        }

                        if expandedBook == book.name {
                            BookInfoView(book: book)
                        }
                    }
                    .listRowBackground(Color.readerBackground)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.readerBackground)
        }
    }

    private func toggleSelection(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }
}

struct BookRow: View {
    let book: Book
    let icon: String
    let isSelected: Bool
    let isSelecting: Bool
    let isExpanded: Bool
    let showInfo: Bool
    let onToggleInfo: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            if isSelecting {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.readerBlue : Color.readerSecondary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.readerBlue)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }

            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 24)

            Text(book.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showInfo {
                Button(action: onToggleInfo) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.readerBlue)
                        .padding(8)
                        .background(isExpanded ? Color.readerBlue.opacity(0.15) : .clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.readerSecondary)
            }
        }
        .padding(.vertical, 16)
        .background(Color.readerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}

struct BookInfoView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if book.hasInfo {
                let tags = book.tags.split(whereSeparator: \.isWhitespace).map(String.init).filter { $0.hasPrefix("#") }
                if !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(String(tag.dropFirst()))
                                .font(.system(size: 12))
                                .foregroundColor(.readerText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                if !book.summary.isEmpty {
                    Text(book.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.readerText)
                        .lineSpacing(4)
                }
            } else {
                Text("暂无简介信息")
                    .font(.system(size: 14))
                    .foregroundColor(.readerSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding(12)
        .background(Color.readerPanel)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}

struct ReaderView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]
    let bookName: String
    @State private var showNav = true
    @State private var showDelete = false
    @State private var shareURL: ShareURL?
    @State private var paragraphs: [String] = ["加载中..."]

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(bookName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .padding(.bottom, 20)

                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph.isEmpty ? " " : paragraph)
                            .font(.system(size: CGFloat(store.fontSize)))
                            .foregroundColor(.readerText)
                            .lineSpacing(CGFloat(store.fontSize) * 0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 69)
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(Color.readerBackground.ignoresSafeArea())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showNav.toggle()
                }
            }

            ReaderNavBar(
                visible: showNav,
                backTitle: "书架",
                isFavorite: store.favorites.contains(bookName),
                isInTrash: store.trashNames.contains(bookName),
                onBack: { pop() },
                onDownload: {
                    if let url = store.exportURL(for: bookName) {
                        shareURL = ShareURL(url: url)
                    }
                },
                onFavorite: { store.toggleFavorite(bookName) },
                onRestore: {
                    store.restoreFromTrash(bookName)
                    pop()
                },
                onDelete: { showDelete = true }
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            paragraphs = store.content(for: bookName).components(separatedBy: .newlines)
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("删除书籍", isPresented: $showDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if store.trashNames.contains(bookName) {
                    store.deletePermanently(bookName)
                } else {
                    store.moveToTrash(bookName)
                }
                pop()
            }
        } message: {
            Text(store.trashNames.contains(bookName) ? "确定要永久删除这本书吗？此操作无法撤销。" : "确定要删除这本书吗？")
        }
    }

    private func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}

struct ReaderNavBar: View {
    let visible: Bool
    let backTitle: String
    let isFavorite: Bool
    let isInTrash: Bool
    let onBack: () -> Void
    let onDownload: () -> Void
    let onFavorite: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Text("‹ \(backTitle)")
                    .font(.system(size: 17))
            }
            Spacer()
            HStack(spacing: 15) {
                Button(action: onDownload) { Image(systemName: "square.and.arrow.down") }
                if isInTrash {
                    Button(action: onRestore) { Image(systemName: "arrow.counterclockwise") }
                } else {
                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .readerYellow : .readerBlue)
                    }
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.readerRed)
                }
            }
            .font(.system(size: 20))
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .frame(height: 64)
        .background(Color.readerBackground.opacity(0.62).blur(radius: 0.2))
        .background(.ultraThinMaterial)
        .offset(y: visible ? 0 : -80)
        .animation(.easeInOut(duration: 0.25), value: visible)
    }
}

struct RecentView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]
    @State private var selected = Set<String>()
    @State private var showClear = false
    @State private var deleteTarget: DeleteTarget?

    private var displayedBooks: [Book] {
        let byName = Dictionary(uniqueKeysWithValues: store.books.map { ($0.name, $0) })
        return store.recent.compactMap { byName[$0.name] }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                BackHeader(title: "最近阅读", backTitle: "书架", path: $path) {
                    if !displayedBooks.isEmpty {
                        Button("清空") { showClear = true }
                    }
                }
                if displayedBooks.isEmpty {
                    EmptyState(text: "暂无阅读记录")
                } else {
                    BookListView(
                        books: displayedBooks,
                        icon: "doc.text",
                        selected: $selected,
                        expandedBook: .constant(nil),
                        onOpen: openBook,
                        onDelete: { deleteTarget = .singleRecent($0) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .background(Color.readerBackground.ignoresSafeArea())

            if !selected.isEmpty {
                SelectionFooter {
                    FooterAction(title: "删除记录", systemImage: "trash", tint: .readerRed) {
                        deleteTarget = .multipleRecent(Array(selected))
                    }
                    FooterAction(title: "取消", systemImage: "xmark", tint: .white) {
                        selected.removeAll()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("清空最近阅读", isPresented: $showClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { store.clearRecent() }
        } message: {
            Text("确定要清空所有最近阅读记录吗？此操作无法撤销。")
        }
        .alert(item: $deleteTarget) { target in
            Alert(
                title: Text("删除记录"),
                message: Text(target.message),
                primaryButton: .destructive(Text("删除")) {
                    target.names.forEach(store.removeFromRecent)
                    selected.removeAll()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private func openBook(_ name: String) {
        store.addToRecent(name)
        path.append(.reader(name))
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]
    @State private var selected = Set<String>()

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                BackHeader(title: "我的收藏", backTitle: "书架", path: $path)
                if store.favoriteBooks.isEmpty {
                    EmptyState(text: "暂无收藏书籍")
                } else {
                    BookListView(
                        books: store.favoriteBooks,
                        icon: "star.fill",
                        selected: $selected,
                        expandedBook: .constant(nil),
                        onOpen: openBook,
                        onDelete: { store.toggleFavorite($0) },
                        onRemove: { store.toggleFavorite($0) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .background(Color.readerBackground.ignoresSafeArea())

            if !selected.isEmpty {
                SelectionFooter {
                    FooterAction(title: "取消收藏", systemImage: "trash", tint: .readerRed) {
                        selected.forEach(store.toggleFavorite)
                        selected.removeAll()
                    }
                    FooterAction(title: "取消", systemImage: "xmark", tint: .white) {
                        selected.removeAll()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func openBook(_ name: String) {
        store.addToRecent(name)
        path.append(.reader(name))
    }
}

struct TrashView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]
    @State private var selected = Set<String>()
    @State private var deleteTarget: DeleteTarget?

    private var isAllSelected: Bool {
        !store.trashBooks.isEmpty && selected.count == store.trashBooks.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    if selected.isEmpty {
                        Button("‹ 设置") { if !path.isEmpty { path.removeLast() } }
                    } else {
                        Button(isAllSelected ? "取消全选" : "全选") {
                            if isAllSelected {
                                selected.removeAll()
                            } else {
                                selected = Set(store.trashBooks.map(\.name))
                            }
                        }
                    }
                    Spacer()
                    Button(selected.isEmpty ? "选择" : "完成") {
                        if selected.isEmpty {
                            selected = []
                        } else {
                            selected.removeAll()
                        }
                    }
                }
                .font(.system(size: 17))
                .frame(height: 44)
                .padding(.top, 10)

                Text("废纸篓")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)

                if store.trashBooks.isEmpty {
                    EmptyState(text: "废纸篓为空")
                } else {
                    BookListView(
                        books: store.trashBooks,
                        icon: "doc.text",
                        selected: $selected,
                        expandedBook: .constant(nil),
                        onOpen: { path.append(.reader($0)) },
                        onDelete: { deleteTarget = .singlePermanent($0) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .background(Color.readerBackground.ignoresSafeArea())

            if !selected.isEmpty {
                SelectionFooter {
                    FooterAction(title: "恢复", systemImage: "arrow.counterclockwise") {
                        selected.forEach(store.restoreFromTrash)
                        selected.removeAll()
                    }
                    FooterAction(title: "删除", systemImage: "trash", tint: .readerRed) {
                        deleteTarget = .multiplePermanent(Array(selected))
                    }
                    FooterAction(title: "取消", systemImage: "xmark", tint: .white) {
                        selected.removeAll()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert(item: $deleteTarget) { target in
            Alert(
                title: Text("永久删除"),
                message: Text(target.message),
                primaryButton: .destructive(Text("删除")) {
                    target.names.forEach(store.deletePermanently)
                    selected.removeAll()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ReaderStore
    @Binding var path: [Route]
    @State private var showAbout = false
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackHeader(title: "设置", backTitle: "返回", path: $path)

                SettingsSection(title: "阅读设置") {
                    StepperRow(icon: "Aa", title: "字体大小", value: "\(store.fontSize)") {
                        store.setFontSize(store.fontSize - 1)
                    } increment: {
                        store.setFontSize(store.fontSize + 1)
                    }
                    StepperRow(icon: "🕒", title: "最近阅读记录数", value: "\(store.recentLimit)") {
                        store.setRecentLimit(store.recentLimit - 5)
                    } increment: {
                        store.setRecentLimit(store.recentLimit + 5)
                    }
                }

                SettingsSection(title: "搜索设置") {
                    HStack {
                        Text("🔍").frame(width: 24)
                        Text("仅搜索文件名")
                            .font(.system(size: 17))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.searchMode == "filename" },
                            set: { store.setSearchMode($0 ? "filename" : "fulltext") }
                        ))
                        .labelsHidden()
                    }
                    .padding(16)

                    StepperRow(icon: "#", title: "搜索结果数量", value: searchLimitDisplay) {
                        decreaseSearchLimit()
                    } increment: {
                        increaseSearchLimit()
                    }
                }

                if store.searchResultLimit == 0 {
                    Text("⚠️ 无限制可能导致搜索缓慢")
                        .font(.system(size: 12))
                        .foregroundColor(.readerOrange)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 5)
                        .padding(.trailing, 12)
                }

                SettingsSection(title: "数据管理") {
                    SettingsLink(icon: "🗑️", title: "废纸篓") { path.append(.trash) }
                }

                SettingsSection(title: "关于") {
                    SettingsLink(icon: "📖", title: "关于本地阅读器") { showAbout = true }
                    SettingsValue(icon: "📦", title: "版本", value: "1.0")
                    SettingsLink(icon: "🔒", title: "隐私政策") { showPrivacy = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.readerBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPrivacy) {
            InfoSheet(title: "隐私政策", buttonTitle: "关闭") {
                Group {
                    Text("数据存储").fontWeight(.bold).foregroundColor(.white)
                    Text("本应用所有数据均存储在您的设备本地，不会上传至任何服务器。")
                    Text("权限使用").fontWeight(.bold).foregroundColor(.white)
                    Text("本应用仅读取应用内置和本地保存的书籍数据，不会访问其他任何数据。")
                    Text("第三方服务").fontWeight(.bold).foregroundColor(.white)
                    Text("本应用不包含任何第三方跟踪或分析服务。")
                }
            }
        }
        .sheet(isPresented: $showAbout) {
            InfoSheet(title: "关于本地阅读器", buttonTitle: "关闭") {
                Group {
                    Text("本项目是一款专为移动端优化的本地小说阅读器，已迁移为原生 iOS 应用。")
                    Text("SwiftUI - 原生页面和交互")
                    Text("SQLite + FTS5 - 本地持久化、全文检索和废纸篓管理")
                    Text("声明：本阅读器仅提供本地文件阅读功能，所有小说及内容物均由用户自行添加，与本项目无关。")
                        .foregroundColor(.readerOrange)
                        .padding(10)
                        .background(Color.readerOrange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("🚀 计划中的功能：支持自定义与 OpenAI API 格式兼容的 API，以支持导入新小说时自动添加标签和简介")
                        .foregroundColor(.readerGreen)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var searchLimitDisplay: String {
        store.searchResultLimit == 0 ? "无限制" : "\(store.searchResultLimit)"
    }

    private func increaseSearchLimit() {
        let current = store.searchResultLimit
        if current == 250 {
            store.setSearchResultLimit(0)
        } else if current != 0 {
            store.setSearchResultLimit(current + 50)
        }
    }

    private func decreaseSearchLimit() {
        let current = store.searchResultLimit
        if current == 0 {
            store.setSearchResultLimit(250)
        } else if current > 50 {
            store.setSearchResultLimit(current - 50)
        }
    }
}

struct HeaderView<Actions: View>: View {
    let title: String
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 15) {
                actions
            }
            .font(.system(size: 24))
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
}

struct BackHeader<Trailing: View>: View {
    let title: String
    let backTitle: String
    @Binding var path: [Route]
    @ViewBuilder var trailing: Trailing

    init(title: String, backTitle: String, path: Binding<[Route]>, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.backTitle = backTitle
        self._path = path
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button("‹ \(backTitle)") {
                    if !path.isEmpty { path.removeLast() }
                }
                .font(.system(size: 17))
                Spacer()
                trailing
            }
            .frame(height: 44)

            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 20)
        }
        .padding(.top, 10)
    }
}

struct EmptyState: View {
    let text: String
    var body: some View {
        Spacer()
        Text(text)
            .foregroundColor(.readerSecondary)
            .frame(maxWidth: .infinity)
        Spacer()
    }
}

struct SelectionFooter<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 15)
        .background(Color.readerFooter.ignoresSafeArea(edges: .bottom))
        .transition(.move(edge: .bottom))
    }
}

struct FooterAction: View {
    let title: String
    let systemImage: String
    var tint: Color = .readerBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(tint)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.readerSecondary)
                .padding(.leading, 16)
                .padding(.top, 20)
            VStack(spacing: 0) {
                content
            }
            .background(Color.readerPanel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct StepperRow: View {
    let icon: String
    let title: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 17))
            Spacer()
            HStack(spacing: 10) {
                Button("-", action: decrement)
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.readerSecondary)
                    .frame(minWidth: 40)
                Button("+", action: increment)
            }
            .buttonStyle(StepperButtonStyle())
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)
                .padding(.leading, 55)
        }
    }
}

struct StepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .light))
            .foregroundColor(.white)
            .frame(width: 44, height: 32)
            .background(configuration.isPressed ? Color.readerPressed : Color.readerControl)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SettingsValue: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(icon).frame(width: 24)
            Text(title)
                .font(.system(size: 17))
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.readerSecondary)
        }
        .padding(16)
    }
}

struct SettingsLink: View {
    let icon: String
    let title: String
    var value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(icon).frame(width: 24)
                Text(title)
                    .font(.system(size: 17))
                Spacer()
                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundColor(.readerSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.readerSecondary)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct InfoSheet<Content: View>: View {
    let title: String
    let buttonTitle: String
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .font(.system(size: 14))
            .foregroundColor(.readerSecondary)
            Button(buttonTitle) { dismiss() }
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.readerBlue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 4)
        }
        .padding(24)
        .background(Color.readerPanel.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

struct ShareURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum DeleteTarget: Identifiable {
    case single(String)
    case multiple([String])
    case singleRecent(String)
    case multipleRecent([String])
    case singlePermanent(String)
    case multiplePermanent([String])

    var id: String {
        message + names.joined(separator: "|")
    }

    var names: [String] {
        switch self {
        case .single(let name), .singleRecent(let name), .singlePermanent(let name):
            return [name]
        case .multiple(let names), .multipleRecent(let names), .multiplePermanent(let names):
            return names
        }
    }

    var message: String {
        switch self {
        case .single(let name):
            return "删除 \"\(name)\"？"
        case .multiple(let names):
            return "删除 \(names.count) 项？"
        case .singleRecent(let name):
            return "删除 \"\(name)\" 的阅读记录？"
        case .multipleRecent(let names):
            return "删除 \(names.count) 条记录？"
        case .singlePermanent(let name):
            return "确定要永久删除 \"\(name)\" 吗？"
        case .multiplePermanent(let names):
            return "确定要永久删除选中的 \(names.count) 项吗？此操作无法撤销。"
        }
    }
}

extension Color {
    static let readerBackground = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let readerPanel = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    static let readerFooter = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    static let readerControl = Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255)
    static let readerPressed = Color(red: 72 / 255, green: 72 / 255, blue: 74 / 255)
    static let readerText = Color(red: 209 / 255, green: 209 / 255, blue: 214 / 255)
    static let readerSecondary = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let readerBlue = Color(red: 204 / 255, green: 204 / 255, blue: 210 / 255)
    static let readerRed = Color(red: 1, green: 69 / 255, blue: 58 / 255)
    static let readerYellow = Color(red: 1, green: 214 / 255, blue: 10 / 255)
    static let readerOrange = Color(red: 1, green: 149 / 255, blue: 0)
    static let readerGreen = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
}
#endif

extension Notification.Name {
    static let readerStoreDidChange = Notification.Name("readerStoreDidChange")
}

final class ReaderStore {
    static let shared = ReaderStore()
    private static let recentRetentionInterval: TimeInterval = 30 * 24 * 60 * 60

    private var database: SQLiteStore?
    private let searchLock = NSLock()
    private var activeSearchToken: SearchCancellationToken?
    private var recentByName: [String: RecentBook] = [:]
    private var activeBooksByName: [String: Book] = [:]
    private var trashBooksByName: [String: Book] = [:]
    private var sortRequestID = UUID()

    private(set) var books: [Book] = []
    private(set) var trashBooks: [Book] = []
    private(set) var favorites = Set<String>()
    private(set) var recent: [RecentBook] = []
    private(set) var fontSize = 18
    private(set) var searchMode = "fulltext"
    private(set) var bookSortMode: BookSortMode = .name
    private(set) var searchHistory: [String] = []
    private(set) var pinnedSearchHistory = Set<String>()
    private(set) var searchPresets: [SearchPreset] = []
    private(set) var stateWarning: String?

    private init() {}

    private struct Snapshot {
        let books: [Book]
        let trashBooks: [Book]
        let favorites: Set<String>
        let recent: [RecentBook]
        let preferences: [String: String]
        let stateWarning: String?
    }

    func load(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let database = try SQLiteStore()
                let snapshot = try Self.makeSnapshot(database: database)
                DispatchQueue.main.async {
                    self.database = database
                    self.apply(snapshot)
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func makeSnapshot(database: SQLiteStore) throws -> Snapshot {
        let preferences = try database.preferences()
        let sortMode = BookSortMode(rawValue: preferences["bookSortMode"] ?? "") ?? .name
        return Snapshot(
            books: try database.books(status: .active, sortMode: sortMode),
            trashBooks: try database.books(status: .deleted, sortMode: sortMode),
            favorites: try database.favorites(),
            recent: try database.recent(),
            preferences: preferences,
            stateWarning: database.stateWarning
        )
    }

    private func apply(_ snapshot: Snapshot) {
        books = snapshot.books
        trashBooks = snapshot.trashBooks
        favorites = snapshot.favorites
        recent = Self.recentWithinRetention(snapshot.recent)
        bookSortMode = BookSortMode(rawValue: snapshot.preferences["bookSortMode"] ?? "") ?? .name
        rebuildIndexes()
        fontSize = Int(snapshot.preferences["fontSize"] ?? "") ?? 18
        searchMode = snapshot.preferences["searchMode"] ?? "fulltext"
        searchHistory = Self.decodeSearchHistory(snapshot.preferences["searchHistory"])
        pinnedSearchHistory = Set(Self.decodeSearchHistory(snapshot.preferences["pinnedSearchHistory"]))
        searchPresets = (try? database?.searchPresets()) ?? []
        stateWarning = snapshot.stateWarning
        if recent.count != snapshot.recent.count {
            do {
                try database?.replaceRecent(recent)
            } catch {
                recordStateWriteFailure(error)
            }
        }
    }

    private static func recentWithinRetention(_ recent: [RecentBook]) -> [RecentBook] {
        let cutoff = Int64((Date().timeIntervalSince1970 - recentRetentionInterval) * 1000)
        return recent.filter { $0.timestamp >= cutoff }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .readerStoreDidChange, object: self)
    }

    private func recordStateWriteFailure(_ error: Error) {
        let message = "状态写入失败：\(error)"
        print("ReaderState write failed: \(error)")
        stateWarning = message
    }

    private func ensurePersistentState() throws -> SQLiteStore {
        guard let database else { throw DatabaseError.message("数据库未就绪") }
        guard database.isUsingPersistentState else {
            throw DatabaseError.message(database.stateWarning ?? "状态库未持久化")
        }
        return database
    }

    private func rebuildIndexes() {
        activeBooksByName = Dictionary(uniqueKeysWithValues: books.map { ($0.name, $0) })
        trashBooksByName = Dictionary(uniqueKeysWithValues: trashBooks.map { ($0.name, $0) })
        recentByName = Dictionary(uniqueKeysWithValues: recent.map { ($0.name, $0) })
    }

    private func sortBookLists() {
        books = Self.sorted(books, mode: bookSortMode)
        trashBooks = Self.sorted(trashBooks, mode: bookSortMode)
    }

    private static func sorted(_ values: [Book], mode: BookSortMode) -> [Book] {
        values.sorted { lhs, rhs in
            compare(lhs, rhs, mode: mode)
        }
    }

    private static func compare(_ lhs: Book, _ rhs: Book, mode: BookSortMode) -> Bool {
        switch mode {
        case .name:
            if lhs.id != rhs.id {
                return lhs.id < rhs.id
            }
            return BookOrdering.nameAscending(lhs.name, rhs.name)
        case .sizeDescending:
            if lhs.byteSize != rhs.byteSize {
                return lhs.byteSize > rhs.byteSize
            }
            return lhs.id < rhs.id
        case .sizeAscending:
            if lhs.byteSize != rhs.byteSize {
                return lhs.byteSize < rhs.byteSize
            }
            return lhs.id < rhs.id
        }
    }

    private func insert(_ book: Book, into values: inout [Book]) {
        let mode = bookSortMode
        var lower = 0
        var upper = values.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if Self.compare(values[middle], book, mode: mode) {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        values.insert(book, at: lower)
    }

    private func replaceBookInSortedLists(originalName: String, with book: Book) {
        let oldStatus: BookStatus?
        if let index = books.firstIndex(where: { $0.name == originalName }) {
            books.remove(at: index)
            oldStatus = .active
        } else if let index = trashBooks.firstIndex(where: { $0.name == originalName }) {
            trashBooks.remove(at: index)
            oldStatus = .deleted
        } else {
            oldStatus = book.status
        }

        switch oldStatus ?? book.status {
        case .active:
            insert(book, into: &books)
        case .deleted:
            insert(Book(
                id: book.id,
                name: book.name,
                status: .deleted,
                byteSize: book.byteSize,
                hasInfo: book.hasInfo,
                tags: book.tags,
                summary: book.summary
            ), into: &trashBooks)
        }
    }

    private func replaceActiveBook(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.name == book.name }) else { return }
        books[index] = book
        activeBooksByName[book.name] = book
    }

    private func replaceBook(originalName: String, with book: Book) {
        replaceBookInSortedLists(originalName: originalName, with: book)
        if favorites.remove(originalName) != nil {
            favorites.insert(book.name)
        }
        recent = recent.map { item in
            item.name == originalName ? RecentBook(name: book.name, timestamp: item.timestamp) : item
        }
        rebuildIndexes()
    }

    var favoriteBooks: [Book] {
        books.filter { favorites.contains($0.name) }
    }

    var recentBooks: [Book] {
        recent.compactMap { activeBooksByName[$0.name] }
    }

    var activeNames: Set<String> {
        Set(books.map(\.name))
    }

    var trashNames: Set<String> {
        Set(trashBooksByName.keys)
    }

    func book(named name: String) -> Book? {
        activeBooksByName[name] ?? trashBooksByName[name]
    }

    func detailedBook(named name: String) -> Book? {
        if let database, let book = try? database.bookInfo(for: name) {
            replaceActiveBook(book)
            return book
        }
        return book(named: name)
    }

    func content(for name: String) -> String {
        guard let database else { return "加载中..." }
        return (try? database.content(for: name)) ?? "文件未找到。"
    }

    func updateBook(
        originalName: String,
        title: String,
        content: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let database else {
            completion(.failure(DatabaseError.message("数据库未就绪")))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let book = try database.updateBook(originalName: originalName, newName: title, content: content)
                DispatchQueue.main.async {
                    self.replaceBook(originalName: originalName, with: book)
                    self.notifyChange()
                    completion(.success(book.name))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func repairBookEncoding(name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let database else {
            completion(.failure(DatabaseError.message("数据库未就绪")))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let rawContent = try database.rawContent(for: name) else {
                    throw DatabaseError.message("文件未找到")
                }
                let repaired = SearchText.forceRepairMojibake(rawContent)
                let book = try database.updateBook(originalName: name, newName: name, content: repaired)
                DispatchQueue.main.async {
                    self.replaceBook(originalName: name, with: book)
                    self.notifyChange()
                    completion(.success(repaired))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func toggleFavorite(_ name: String) {
        let enabled = !favorites.contains(name)
        do {
            try ensurePersistentState().setFavorite(name, enabled: enabled)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        if enabled {
            favorites.insert(name)
        } else {
            favorites.remove(name)
        }
        notifyChange()
    }

    func addToRecent(_ name: String) {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        var nextRecent = recent
        nextRecent.removeAll { $0.name == name }
        nextRecent.insert(RecentBook(name: name, timestamp: timestamp), at: 0)
        nextRecent = Self.recentWithinRetention(nextRecent)
        recent = nextRecent
        rebuildIndexes()
        notifyChange()

        guard let database else {
            recordStateWriteFailure(DatabaseError.message("数据库未就绪"))
            notifyChange()
            return
        }
        guard database.isUsingPersistentState else {
            recordStateWriteFailure(DatabaseError.message(database.stateWarning ?? "状态库未持久化"))
            notifyChange()
            return
        }
        DispatchQueue.global(qos: .utility).async {
            do {
                try database.replaceRecent(nextRecent)
            } catch {
                DispatchQueue.main.async {
                    self.recordStateWriteFailure(error)
                    self.notifyChange()
                }
            }
        }
    }

    func removeFromRecent(_ name: String) {
        var nextRecent = recent
        nextRecent.removeAll { $0.name == name }
        do {
            try ensurePersistentState().replaceRecent(nextRecent)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        recent = nextRecent
        recentByName.removeValue(forKey: name)
        rebuildIndexes()
        notifyChange()
    }

    func clearRecent() {
        do {
            try ensurePersistentState().replaceRecent([])
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        recent = []
        rebuildIndexes()
        notifyChange()
    }

    func setBookSortMode(_ mode: BookSortMode) {
        guard bookSortMode != mode else { return }
        do {
            try ensurePersistentState().setPreference("bookSortMode", value: mode.rawValue)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        bookSortMode = mode

        let requestID = UUID()
        sortRequestID = requestID
        let currentBooks = books
        let currentTrashBooks = trashBooks
        DispatchQueue.global(qos: .userInitiated).async {
            let sortedBooks = Self.sorted(currentBooks, mode: mode)
            let sortedTrashBooks = Self.sorted(currentTrashBooks, mode: mode)
            DispatchQueue.main.async {
                guard self.sortRequestID == requestID, self.bookSortMode == mode else { return }
                self.books = sortedBooks
                self.trashBooks = sortedTrashBooks
                self.rebuildIndexes()
                self.notifyChange()
            }
        }
    }

    func moveToTrash(_ name: String) {
        guard let index = books.firstIndex(where: { $0.name == name }) else { return }
        do {
            try ensurePersistentState().moveToTrash(name)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        let book = books.remove(at: index)
        insert(Book(
            id: book.id,
            name: book.name,
            status: .deleted,
            byteSize: book.byteSize,
            hasInfo: book.hasInfo,
            tags: book.tags,
            summary: book.summary
        ), into: &trashBooks)
        favorites.remove(name)
        recent.removeAll { $0.name == name }
        rebuildIndexes()
        notifyChange()
    }

    func restoreFromTrash(_ name: String) {
        guard let index = trashBooks.firstIndex(where: { $0.name == name }) else { return }
        do {
            try ensurePersistentState().move(name, to: .active)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        let book = trashBooks.remove(at: index)
        insert(Book(
            id: book.id,
            name: book.name,
            status: .active,
            byteSize: book.byteSize,
            hasInfo: book.hasInfo,
            tags: book.tags,
            summary: book.summary
        ), into: &books)
        rebuildIndexes()
        notifyChange()
    }

    func deletePermanently(_ name: String) {
        do {
            try ensurePersistentState().deletePermanently(name)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        trashBooks.removeAll { $0.name == name }
        books.removeAll { $0.name == name }
        favorites.remove(name)
        recent.removeAll { $0.name == name }
        rebuildIndexes()
        notifyChange()
    }

    func setFontSize(_ value: Int) {
        let newValue = min(max(value, 14), 28)
        do {
            try ensurePersistentState().setPreference("fontSize", value: String(newValue))
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        fontSize = newValue
        notifyChange()
    }

    func setSearchMode(_ value: String) {
        do {
            try ensurePersistentState().setPreference("searchMode", value: value)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        searchMode = value
        notifyChange()
    }

    func addSearchHistory(_ query: String) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        var nextHistory = searchHistory
        nextHistory.removeAll { $0.caseInsensitiveCompare(cleaned) == .orderedSame }
        nextHistory.insert(cleaned, at: 0)
        nextHistory = Array(nextHistory.prefix(20))
        let nextPinned = pinnedSearchHistory.filter { pinned in
            nextHistory.contains { $0.caseInsensitiveCompare(pinned) == .orderedSame }
        }
        do {
            try persistSearchHistory(nextHistory, pinned: nextPinned)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        searchHistory = nextHistory
        pinnedSearchHistory = nextPinned
        notifyChange()
    }

    func removeSearchHistory(_ query: String) {
        var nextHistory = searchHistory
        nextHistory.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        var nextPinned = pinnedSearchHistory
        nextPinned.remove(query)
        do {
            try persistSearchHistory(nextHistory, pinned: nextPinned)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        searchHistory = nextHistory
        pinnedSearchHistory = nextPinned
        notifyChange()
    }

    func togglePinnedSearchHistory(_ query: String) {
        var nextPinned = pinnedSearchHistory
        if nextPinned.contains(query) {
            nextPinned.remove(query)
        } else {
            nextPinned.insert(query)
        }
        do {
            try persistSearchHistory(searchHistory, pinned: nextPinned)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        pinnedSearchHistory = nextPinned
        notifyChange()
    }

    func clearSearchHistory() {
        do {
            try persistSearchHistory([], pinned: [])
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        searchHistory = []
        pinnedSearchHistory = []
        notifyChange()
    }

    private func persistSearchHistory(_ history: [String], pinned: Set<String>) throws {
        guard
            let data = try? JSONSerialization.data(withJSONObject: history),
            let value = String(data: data, encoding: .utf8)
        else { throw DatabaseError.message("搜索历史序列化失败") }
        let pinnedData = try JSONSerialization.data(withJSONObject: Array(pinned))
        guard let pinnedValue = String(data: pinnedData, encoding: .utf8) else {
            throw DatabaseError.message("置顶搜索历史序列化失败")
        }
        let database = try ensurePersistentState()
        try database.setPreference("searchHistory", value: value)
        try database.setPreference("pinnedSearchHistory", value: pinnedValue)
    }

    private static func decodeSearchHistory(_ value: String?) -> [String] {
        guard
            let value,
            let data = value.data(using: .utf8),
            let decoded = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return decoded.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func search(
        query: String,
        mode: String,
        progress: @escaping (SearchProgress) -> Void,
        onResult: ((SearchResult) -> Void)? = nil,
        completion: @escaping ([SearchResult]) -> Void
    ) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let database else {
            completion([])
            return
        }

        let token = beginSearch(using: database)
        let presetSnapshot = searchPresets
        DispatchQueue.global(qos: .userInitiated).async {
            let results: [SearchResult]
            do {
                let presetSeed = mode == "fulltext"
                    ? self.cachedPresetSeed(for: cleaned, presets: presetSnapshot, database: database)
                    : nil
                if let presetSeed, presetSeed.isExact {
                    results = presetSeed.results
                    guard !token.isCancelled else { return }
                    DispatchQueue.main.async {
                        guard !token.isCancelled else { return }
                        self.finishSearch(token)
                        completion(results)
                    }
                    return
                }

                let progressHandler: (SearchProgress) -> Void = { progressValue in
                    guard !token.isCancelled else { return }
                    DispatchQueue.main.async {
                        guard !token.isCancelled else { return }
                        progress(progressValue)
                    }
                }
                let resultHandler: (SearchResult) -> Void = { result in
                    guard !token.isCancelled else { return }
                    DispatchQueue.main.async {
                        guard !token.isCancelled else { return }
                        onResult?(result)
                    }
                }
                if let names = presetSeed?.candidateNames, !names.isEmpty {
                    results = try database.searchContent(
                        query: cleaned,
                        candidateNames: names,
                        limit: 0,
                        isCancelled: { token.isCancelled },
                        progress: progressHandler,
                        onResult: resultHandler
                    )
                } else {
                    results = try database.search(
                        query: cleaned,
                        mode: mode,
                        limit: 0,
                        isCancelled: { token.isCancelled },
                        progress: progressHandler,
                        onResult: resultHandler
                    )
                }
            } catch SearchCancellation.cancelled {
                return
            } catch {
                results = []
            }
            guard !token.isCancelled else { return }
            DispatchQueue.main.async {
                guard !token.isCancelled else { return }
                self.finishSearch(token)
                completion(results)
            }
        }
    }

    private func cachedPresetSeed(
        for query: String,
        presets: [SearchPreset],
        database: SQLiteStore
    ) -> (isExact: Bool, results: [SearchResult], candidateNames: [String]?)? {
        let normalized = SearchText.normalizedQuery(query)
        guard !normalized.isEmpty else { return nil }
        let matchingPresets = presets
            .map(\.query)
            .filter { SearchText.query(normalized, containsPreset: $0) }
        guard !matchingPresets.isEmpty else { return nil }

        let presetResults = matchingPresets.map { preset in
            (preset, (try? database.searchPresetResults(query: preset)) ?? [])
        }.filter { !$0.1.isEmpty }
        guard !presetResults.isEmpty else { return nil }

        if let exact = presetResults.first(where: { SearchText.normalizedQuery($0.0) == normalized }),
           !exact.1.isEmpty {
            return (true, exact.1, nil)
        }

        var candidateNames: Set<String>?
        for (_, results) in presetResults {
            let names = Set(results.map(\.bookName))
            candidateNames = candidateNames.map { $0.intersection(names) } ?? names
        }

        let names = Array(candidateNames ?? [])
        guard !names.isEmpty else { return nil }
        return (false, [], names)
    }

    func searchSnippet(
        bookName: String,
        query: String,
        completion: @escaping (String) -> Void
    ) {
        guard let database else {
            completion("")
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let snippet = (try? database.searchSnippet(bookName: bookName, query: query)) ?? ""
            DispatchQueue.main.async {
                completion(snippet)
            }
        }
    }

    func addSearchPreset(
        _ query: String,
        progress: ((SearchProgress) -> Void)? = nil,
        completion: @escaping (Result<[SearchResult], Error>) -> Void
    ) {
        let cleaned = SearchText.normalizedQuery(query)
        guard !cleaned.isEmpty else {
            completion(.failure(DatabaseError.message("搜索词不能为空")))
            return
        }
        let database: SQLiteStore
        do {
            database = try ensurePersistentState()
        } catch {
            recordStateWriteFailure(error)
            completion(.failure(error))
            notifyChange()
            return
        }

        let token = beginSearch(using: database)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let names = try database.searchCandidateNames(query: cleaned, limit: 0, isCancelled: { token.isCancelled }) { progressValue in
                    guard !token.isCancelled else { return }
                    DispatchQueue.main.async {
                        guard !token.isCancelled else { return }
                        progress?(progressValue)
                    }
                }
                let results = names.map { SearchResult(bookName: $0, snippet: "") }
                guard !token.isCancelled else { return }
                try database.saveSearchPreset(query: cleaned, results: results)
                let presets = (try? database.searchPresets()) ?? []
                DispatchQueue.main.async {
                    guard !token.isCancelled else { return }
                    self.finishSearch(token)
                    self.searchPresets = presets
                    self.notifyChange()
                    completion(.success(results))
                }
            } catch SearchCancellation.cancelled {
                return
            } catch {
                DispatchQueue.main.async {
                    guard !token.isCancelled else { return }
                    self.finishSearch(token)
                    completion(.failure(error))
                }
            }
        }
    }

    func removeSearchPreset(_ query: String) {
        do {
            try ensurePersistentState().deleteSearchPreset(query: query)
        } catch {
            recordStateWriteFailure(error)
            notifyChange()
            return
        }
        searchPresets.removeAll { $0.query.caseInsensitiveCompare(query) == .orderedSame }
        notifyChange()
    }

    func presetResults(for query: String) -> [SearchResult] {
        guard let database else { return [] }
        return (try? database.searchPresetResults(query: query)) ?? []
    }

    func cancelSearch() {
        let token: SearchCancellationToken?
        searchLock.lock()
        token = activeSearchToken
        activeSearchToken = nil
        searchLock.unlock()

        token?.cancel()
        database?.interrupt()
    }

    private func beginSearch(using database: SQLiteStore) -> SearchCancellationToken {
        let token = SearchCancellationToken()
        let previous: SearchCancellationToken?
        searchLock.lock()
        previous = activeSearchToken
        activeSearchToken = token
        searchLock.unlock()

        previous?.cancel()
        database.interrupt()
        return token
    }

    private func finishSearch(_ token: SearchCancellationToken) {
        searchLock.lock()
        if activeSearchToken === token {
            activeSearchToken = nil
        }
        searchLock.unlock()
    }

    func exportURL(for name: String) -> URL? {
        let content = content(for: name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(Self.safeExportFilename(for: name)).txt")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func safeExportFilename(for name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned = name.unicodeScalars
            .map { illegal.contains($0) ? "_" : String($0) }
            .joined()
            .replacingOccurrences(of: #"\.{2,}"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
        return cleaned.isEmpty ? "未命名" : String(cleaned.prefix(80))
    }
}

final class LoadingViewController: UIViewController {
    private let stackView = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .readerBackground

        titleLabel.text = "正在打开书库"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .readerText
        titleLabel.textAlignment = .center

        messageLabel.text = "正在准备本地数据库和阅读状态。"
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = .readerSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        activityIndicator.startAnimating()

        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    func show(error: Error) {
        activityIndicator.stopAnimating()
        titleLabel.text = "书库初始化失败"
        messageLabel.text = "\(error)"
    }
}

final class RootNavigationController: UINavigationController {
    init(store: ReaderStore) {
        super.init(rootViewController: BookListViewController(kind: .library, store: store))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .readerBackground
        navigationBar.prefersLargeTitles = true
        navigationBar.isTranslucent = true
        interactivePopGestureRecognizer?.isEnabled = true
    }
}

enum BookListKind {
    case library
    case recent
    case favorites
    case trash
}

private enum BookListRow {
    case book(Book)
    case info(Book)
    case searchResult(SearchResult, query: String)
    case searchHistory(String, pinned: Bool)
    case clearSearchHistory

    var infoBookName: String? {
        if case .info(let book) = self {
            return book.name
        }
        return nil
    }
}

private struct SearchCacheKey: Hashable {
    let query: String
    let mode: String

    init(query: String, mode: String) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.mode = mode
    }
}

private struct SearchSnippetCacheKey: Hashable {
    let query: String
    let bookName: String
}

final class BookListViewController: UITableViewController, UISearchBarDelegate {
    private let kind: BookListKind
    private let store: ReaderStore
    private var books: [Book] = []
    private var searchResults: [SearchResult] = []
    private var searchResultCache: [SearchCacheKey: [SearchResult]] = [:]
    private var rows: [BookListRow] = []
    private var expandedBookName: String?
    private var isShowingSearchResults = false
    private var isShowingSearchHistory = false
    private var isSearching = false
    private var searchProgress: SearchProgress?
    private var submittedSearchQuery = ""
    private var submittedSearchMode = "fulltext"
    private var pendingSearchKey: SearchCacheKey?
    private var searchResultNameSet = Set<String>()
    private var bufferedSearchResults: [SearchResult] = []
    private var isSearchResultFlushScheduled = false
    private var snippetCache: [SearchSnippetCacheKey: String] = [:]
    private var pendingSnippetRequests = Set<SearchSnippetCacheKey>()
    private weak var activeSearchBar: UISearchBar?
    private var observer: NSObjectProtocol?
    private let bookCellIdentifier = "BookNameCell"
    private let searchResultCellIdentifier = "SearchResultCell"
    private let infoCellIdentifier = "BookInfoCell"
    private let historyCellIdentifier = "HistoryCell"
    private lazy var searchResultLongPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSearchResultLongPress(_:)))

    init(kind: BookListKind, store: ReaderStore) {
        self.kind = kind
        self.store = store
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleText
        navigationItem.largeTitleDisplayMode = .automatic
        view.backgroundColor = .readerBackground
        tableView.backgroundColor = .readerBackground
        tableView.separatorColor = .readerSeparator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(BookNameCell.self, forCellReuseIdentifier: bookCellIdentifier)
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: searchResultCellIdentifier)
        tableView.register(BookInfoTableViewCell.self, forCellReuseIdentifier: infoCellIdentifier)
        tableView.register(SearchHistoryCell.self, forCellReuseIdentifier: historyCellIdentifier)
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.addGestureRecognizer(searchResultLongPressGesture)
        configureNavigationItems()

        if kind == .library {
            configureSearch()
        }

        observer = NotificationCenter.default.addObserver(
            forName: .readerStoreDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.reloadData()
        }

        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        updateToolbar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if kind == .recent || kind == .trash {
            navigationController?.setToolbarHidden(true, animated: animated)
        }
    }

    private func configureNavigationItems() {
        switch kind {
        case .library:
            navigationItem.leftBarButtonItem = editingButton()
            navigationItem.rightBarButtonItem = compactNavigationItem(
                target: self,
                items: [
                    ("star", #selector(showFavorites)),
                    ("gearshape", #selector(showSettings))
                ],
                menuItems: [
                    ("arrow.up.arrow.down", sortMenu())
                ]
            )
        case .recent:
            navigationItem.rightBarButtonItem = editingButton()
        case .favorites, .trash:
            navigationItem.rightBarButtonItem = editingButton()
        }
    }

    private func editingButton() -> UIBarButtonItem {
        UIBarButtonItem(title: tableView?.isEditing == true ? "完成" : "编辑", style: .plain, target: self, action: #selector(toggleEditingMode))
    }

    private func sortMenu() -> UIMenu {
        UIMenu(title: "排序", children: [
            sortAction(.name),
            sortAction(.sizeDescending),
            sortAction(.sizeAscending)
        ])
    }

    private func sortAction(_ mode: BookSortMode) -> UIAction {
        let image = store.bookSortMode == mode ? UIImage(systemName: "checkmark") : nil
        return UIAction(
            title: mode.title,
            image: image,
            state: store.bookSortMode == mode ? .on : .off
        ) { [weak self] _ in
            self?.store.setBookSortMode(mode)
            self?.configureNavigationItems()
        }
    }

    @objc private func toggleEditingMode() {
        setEditing(!tableView.isEditing, animated: true)
    }

    private var titleText: String {
        switch kind {
        case .library:
            return "书库"
        case .recent:
            return "最近阅读"
        case .favorites:
            return "收藏"
        case .trash:
            return "最近删除"
        }
    }

    private func configureSearch() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "全文搜索"
        searchController.searchBar.scopeButtonTitles = ["全文", "文件名"]
        searchController.searchBar.selectedScopeButtonIndex = 0
        searchController.searchBar.delegate = self
        searchController.searchBar.searchTextField.backgroundColor = .readerControl
        searchController.searchBar.searchTextField.textColor = .readerText
        searchController.searchBar.searchTextField.tintColor = .readerAction
        searchController.searchBar.barTintColor = .readerBackground
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    @objc private func showFavorites() {
        navigationController?.pushViewController(BookListViewController(kind: .favorites, store: store), animated: true)
    }

    @objc private func showSettings() {
        navigationController?.pushViewController(SettingsViewController(store: store), animated: true)
    }

    private func reloadData() {
        switch kind {
        case .library:
            books = store.books
        case .recent:
            books = store.recentBooks
        case .favorites:
            books = store.favoriteBooks
        case .trash:
            books = store.trashBooks
        }
        if let expandedBookName, !displayedBooks().contains(where: { $0.name == expandedBookName }) {
            self.expandedBookName = nil
        }
        rebuildRows()
        tableView.reloadData()
        updateBackground()
    }

    private func displayedBooks() -> [Book] {
        if isShowingSearchHistory {
            return []
        }
        if isShowingSearchResults {
            return searchResults.compactMap { store.book(named: $0.bookName) }
        }
        return books
    }

    private func rebuildRows() {
        if isShowingSearchHistory {
            rows = sortedSearchHistory().map { .searchHistory($0, pinned: store.pinnedSearchHistory.contains($0)) }
            if !store.searchHistory.isEmpty {
                rows.append(.clearSearchHistory)
            }
            return
        }

        if isShowingSearchResults {
            rows = searchResults.map { .searchResult($0, query: submittedSearchQuery) }
            return
        }

        let displayedBooks = displayedBooks()
        rows = displayedBooks.flatMap { book -> [BookListRow] in
            if expandedBookName == book.name {
                return [.book(book), .info(book)]
            }
            return [.book(book)]
        }
    }

    private func sortedSearchHistory() -> [String] {
        store.searchHistory.sorted { lhs, rhs in
            let lhsPinned = store.pinnedSearchHistory.contains(lhs)
            let rhsPinned = store.pinnedSearchHistory.contains(rhs)
            if lhsPinned != rhsPinned {
                return lhsPinned
            }
            let lhsIndex = store.searchHistory.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = store.searchHistory.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    private func updateBackground() {
        let isEmpty = rows.isEmpty
        guard isEmpty else {
            tableView.backgroundView = nil
            return
        }

        let label = UILabel()
        label.text = isSearching ? searchStatusText : emptyText
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        tableView.backgroundView = label
    }

    private var searchStatusText: String {
        guard let searchProgress else { return "搜索中..." }
        if searchProgress.total <= 0 {
            return "搜索中，已处理 \(searchProgress.searched) \(searchProgress.unit)，已找到 \(searchProgress.matched) 项"
        }
        return "搜索中，剩余 \(searchProgress.remaining) \(searchProgress.unit)，已找到 \(searchProgress.matched) 项"
    }

    private func stopSearchProgressTimer() {
        searchProgress = nil
    }

    private var emptyText: String {
        if isShowingSearchHistory { return "暂无搜索历史" }
        if isShowingSearchResults { return "没有搜索结果" }
        switch kind {
        case .library:
            return "暂无书籍"
        case .recent:
            return "暂无最近阅读"
        case .favorites:
            return "暂无收藏"
        case .trash:
            return "最近删除为空"
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .book(let book):
            let cell = tableView.dequeueReusableCell(withIdentifier: bookCellIdentifier, for: indexPath) as! BookNameCell
            cell.configure(
                title: book.name,
                hasInfo: book.hasInfo,
                isExpanded: expandedBookName == book.name,
                showsInfoButton: !tableView.isEditing
            ) { [weak self] in
                self?.toggleInfo(for: book)
            }
            return cell
        case .searchResult(let result, let query):
            let cell = tableView.dequeueReusableCell(withIdentifier: searchResultCellIdentifier, for: indexPath) as! SearchResultCell
            cell.configure(result: result, query: query)
            loadSnippetIfNeeded(for: result, query: query, at: indexPath)
            return cell
        case .info(let book):
            let cell = tableView.dequeueReusableCell(withIdentifier: infoCellIdentifier, for: indexPath) as! BookInfoTableViewCell
            cell.configure(with: book)
            return cell
        case .searchHistory(let query, let pinned):
            let cell = tableView.dequeueReusableCell(withIdentifier: historyCellIdentifier, for: indexPath) as! SearchHistoryCell
            cell.configure(query: query, pinned: pinned)
            return cell
        case .clearSearchHistory:
            let cell = tableView.dequeueReusableCell(withIdentifier: historyCellIdentifier, for: indexPath)
            cell.backgroundColor = .readerBackground
            cell.contentView.backgroundColor = .readerBackground
            cell.selectedBackgroundView = UIView()
            cell.selectedBackgroundView?.backgroundColor = .readerPressed
            cell.multipleSelectionBackgroundView = UIView()
            cell.multipleSelectionBackgroundView?.backgroundColor = .clear
            var content = UIListContentConfiguration.cell()
            content.text = "清除搜索历史"
            content.textProperties.color = .readerAction
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            cell.accessoryType = .none
            return cell
        }
    }

    private func openBook(named name: String) {
        cancelVisibleSearchWork()
        if kind != .trash {
            store.addToRecent(name)
        }
        navigationController?.pushViewController(ReaderViewController(store: store, bookName: name), animated: true)
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !isShowingSearchResults, case .book(let book) = rows[indexPath.row] else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu(children: []) }
            var actions: [UIAction] = [
                UIAction(title: "阅读", image: UIImage(systemName: "book")) { [weak self] _ in
                    self?.openBook(named: book.name)
                }
            ]

            if self.kind == .trash {
                actions.append(UIAction(title: "恢复", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                    self?.store.restoreFromTrash(book.name)
                })
                actions.append(UIAction(title: "永久删除", image: UIImage(systemName: "trash")) { [weak self] _ in
                    self?.store.deletePermanently(book.name)
                })
            } else {
                let isFavorite = self.store.favorites.contains(book.name)
                actions.append(UIAction(title: isFavorite ? "取消收藏" : "收藏", image: UIImage(systemName: isFavorite ? "star.slash" : "star")) { [weak self] _ in
                    self?.store.toggleFavorite(book.name)
                })
                actions.append(UIAction(title: "移到最近删除", image: UIImage(systemName: "trash")) { [weak self] _ in
                    self?.store.moveToTrash(book.name)
                })
            }

            return UIMenu(children: actions)
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            expandedBookName = nil
            rebuildRows()
        }
        tableView.setEditing(editing, animated: animated)
        configureNavigationItems()
        tableView.reloadData()
        tableView.visibleCells.forEach(configureSelectionAppearance)
        updateToolbar()
    }

    private func configureSelectionAppearance(_ cell: UITableViewCell) {
        cell.backgroundColor = .readerBackground
        cell.contentView.backgroundColor = .readerBackground
        cell.multipleSelectionBackgroundView = UIView()
        cell.multipleSelectionBackgroundView?.backgroundColor = .clear
        if cell.selectedBackgroundView == nil {
            cell.selectedBackgroundView = UIView()
        }
        cell.selectedBackgroundView?.backgroundColor = .readerPressed
        clearEditingControlBackgrounds(in: cell)
    }

    private func clearEditingControlBackgrounds(in view: UIView) {
        for subview in view.subviews {
            if String(describing: type(of: subview)).contains("Editing") {
                subview.backgroundColor = .clear
                subview.subviews.forEach { $0.backgroundColor = .clear }
            }
            clearEditingControlBackgrounds(in: subview)
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateToolbar()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateToolbar()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row] {
        case .book(let book):
            openBook(named: book.name)
        case .searchResult(let result, _):
            openBook(named: result.bookName)
        case .searchHistory(let query, _):
            activeSearchBar?.text = query
            runSearch(query: query, mode: currentSearchMode(), recordHistory: true)
            activeSearchBar?.resignFirstResponder()
        case .clearSearchHistory:
            store.clearSearchHistory()
            showSearchHistory()
        case .info:
            break
        }
    }

    @objc private func handleSearchResultLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard isShowingSearchResults, !tableView.isEditing else { return }

        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        guard case .searchResult = rows[indexPath.row] else { return }

        setEditing(true, animated: true)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        updateToolbar()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard isEditing || tableView.isEditing else { return false }
        if case .book = rows[indexPath.row] {
            return true
        }
        if case .searchResult = rows[indexPath.row] {
            return true
        }
        return false
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        switch rows[indexPath.row] {
        case .book, .searchResult:
            return true
        case .searchHistory, .info, .clearSearchHistory:
            return false
        }
    }

    private func toggleInfo(for book: Book) {
        let oldRows = rows
        let targetName = expandedBookName == book.name ? nil : book.name
        expandedBookName = targetName
        if targetName == book.name, let detailedBook = store.detailedBook(named: book.name) {
            books = books.map { $0.name == detailedBook.name ? detailedBook : $0 }
        }
        rebuildRows()

        let deleted = oldRows.enumerated().compactMap { index, row -> IndexPath? in
            if case .info(let oldBook) = row, !rows.contains(where: { $0.infoBookName == oldBook.name }) {
                return IndexPath(row: index, section: 0)
            }
            return nil
        }
        let inserted = rows.enumerated().compactMap { index, row -> IndexPath? in
            if case .info(let newBook) = row, !oldRows.contains(where: { $0.infoBookName == newBook.name }) {
                return IndexPath(row: index, section: 0)
            }
            return nil
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        tableView.performBatchUpdates {
            if !deleted.isEmpty {
                tableView.deleteRows(at: deleted, with: .top)
            }
            if !inserted.isEmpty {
                tableView.insertRows(at: inserted, with: .top)
            }
        } completion: { [weak self] _ in
            self?.tableView.reloadData()
        }
        CATransaction.commit()
    }

    private func updateToolbar() {
        if kind == .recent {
            updateRecentToolbar()
            return
        }
        if kind == .trash {
            updateTrashToolbar()
            return
        }

        guard tableView.isEditing else {
            navigationController?.setToolbarHidden(true, animated: true)
            toolbarItems = nil
            return
        }

        let selectedRows = tableView.indexPathsForSelectedRows ?? []
        let count = selectedRows.count
        let primaryTitle: String
        let primaryAction: Selector

        switch kind {
        case .library:
            primaryTitle = "移到最近删除"
            primaryAction = #selector(deleteSelected)
        case .recent:
            primaryTitle = "移除记录"
            primaryAction = #selector(removeSelectedRecent)
        case .favorites:
            primaryTitle = "取消收藏"
            primaryAction = #selector(unfavoriteSelected)
        case .trash:
            primaryTitle = "永久删除"
            primaryAction = #selector(deleteSelectedPermanently)
        }

        let actionItem = UIBarButtonItem(title: primaryTitle, style: .plain, target: self, action: primaryAction)
        actionItem.tintColor = .readerAction
        actionItem.isEnabled = count > 0
        let countItem = UIBarButtonItem(title: "\(count) 项", style: .plain, target: nil, action: nil)
        countItem.tintColor = .readerSecondary
        toolbarItems = [
            actionItem,
            UIBarButtonItem.flexibleSpace(),
            countItem
        ]
        navigationController?.setToolbarHidden(false, animated: true)
    }

    private func updateRecentToolbar() {
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        let hasRows = !displayedBooks().isEmpty
        let usesSelection = tableView.isEditing
        let clearTitle = usesSelection ? "清除" : "全部清除"
        let clearItem = UIBarButtonItem(title: clearTitle, style: .plain, target: self, action: #selector(clearRecentAction))
        clearItem.tintColor = .readerAction
        clearItem.isEnabled = usesSelection ? selectedCount > 0 : hasRows
        toolbarItems = [
            clearItem,
            UIBarButtonItem.flexibleSpace()
        ]
        navigationController?.setToolbarHidden(false, animated: true)
    }

    private func updateTrashToolbar() {
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        let hasRows = !books.isEmpty
        let usesSelection = tableView.isEditing
        let deleteTitle = usesSelection ? "删除" : "全部删除"
        let restoreTitle = usesSelection ? "恢复" : "全部恢复"
        let enabled = usesSelection ? selectedCount > 0 : hasRows

        let deleteItem = UIBarButtonItem(title: deleteTitle, style: .plain, target: self, action: #selector(deleteTrashAction))
        deleteItem.tintColor = .readerAction
        deleteItem.isEnabled = enabled

        let restoreItem = UIBarButtonItem(title: restoreTitle, style: .plain, target: self, action: #selector(restoreTrashAction))
        restoreItem.tintColor = .readerAction
        restoreItem.isEnabled = enabled

        toolbarItems = [
            deleteItem,
            UIBarButtonItem.flexibleSpace(),
            restoreItem
        ]
        navigationController?.setToolbarHidden(false, animated: true)
    }

    @objc private func deleteSelected() {
        selectedBookNames().forEach(store.moveToTrash)
        setEditing(false, animated: true)
    }

    @objc private func removeSelectedRecent() {
        selectedBookNames().forEach(store.removeFromRecent)
        setEditing(false, animated: true)
    }

    @objc private func unfavoriteSelected() {
        selectedBookNames().forEach(store.toggleFavorite)
        setEditing(false, animated: true)
    }

    @objc private func deleteSelectedPermanently() {
        let names = selectedBookNames()
        confirm(title: "永久删除", message: "确定永久删除选中的 \(names.count) 项？此操作无法撤销。") { [weak self] in
            names.forEach { self?.store.deletePermanently($0) }
            self?.setEditing(false, animated: true)
        }
    }

    @objc private func deleteTrashAction() {
        let names = tableView.isEditing ? selectedBookNames() : books.map(\.name)
        guard !names.isEmpty else { return }
        let title = tableView.isEditing ? "删除所选项目" : "全部删除"
        let message = "确定永久删除 \(names.count) 本书？此操作无法撤销。"
        confirm(title: title, message: message) { [weak self] in
            names.forEach { self?.store.deletePermanently($0) }
            self?.setEditing(false, animated: true)
            self?.updateToolbar()
        }
    }

    @objc private func restoreTrashAction() {
        let names = tableView.isEditing ? selectedBookNames() : books.map(\.name)
        guard !names.isEmpty else { return }
        names.forEach(store.restoreFromTrash)
        setEditing(false, animated: true)
        updateToolbar()
    }

    @objc private func clearRecentAction() {
        let names = tableView.isEditing ? selectedBookNames() : books.map(\.name)
        guard !names.isEmpty else { return }
        let title = tableView.isEditing ? "清除所选记录" : "清空最近阅读"
        let message = tableView.isEditing ? "确定清除选中的 \(names.count) 条记录？" : "确定清空最近 30 天的阅读记录？"
        confirm(title: title, message: message) { [weak self] in
            guard let self else { return }
            if self.tableView.isEditing {
                names.forEach(self.store.removeFromRecent)
            } else {
                self.store.clearRecent()
            }
            self.setEditing(false, animated: true)
            self.updateToolbar()
        }
    }

    private func selectedBookNames() -> [String] {
        (tableView.indexPathsForSelectedRows ?? []).compactMap { indexPath in
            guard indexPath.row < rows.count else { return nil }
            switch rows[indexPath.row] {
            case .book(let book):
                return book.name
            case .searchResult(let result, _):
                return result.bookName
            case .info, .searchHistory, .clearSearchHistory:
                return nil
            }
        }
    }

    @objc private func clearRecent() {
        guard !store.recent.isEmpty else { return }
        confirm(title: "清空最近阅读", message: "确定清空全部最近阅读记录？") { [weak self] in
            self?.store.clearRecent()
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        activeSearchBar = searchBar
        runSearch(query: searchBar.text ?? "", mode: currentSearchMode(from: searchBar), recordHistory: true)
        searchBar.resignFirstResponder()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        activeSearchBar = searchBar
        showSearchHistory()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        activeSearchBar = searchBar
        showSearchHistory()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        store.cancelSearch()
        isShowingSearchResults = false
        isShowingSearchHistory = false
        isSearching = false
        stopSearchProgressTimer()
        searchResults = []
        submittedSearchQuery = ""
        submittedSearchMode = "fulltext"
        pendingSearchKey = nil
        bufferedSearchResults = []
        isSearchResultFlushScheduled = false
        expandedBookName = nil
        rebuildRows()
        tableView.reloadData()
        updateBackground()
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        let mode = selectedScope == 1 ? "filename" : "fulltext"
        activeSearchBar = searchBar
        searchBar.placeholder = mode == "filename" ? "搜索文件名" : "全文搜索"
        if isShowingSearchResults, !submittedSearchQuery.isEmpty {
            runSearch(query: submittedSearchQuery, mode: mode, recordHistory: false)
        } else {
            store.setSearchMode(mode)
            showSearchHistory()
        }
    }

    private func showSearchHistory() {
        guard kind == .library else { return }
        store.cancelSearch()
        isShowingSearchResults = false
        isShowingSearchHistory = true
        isSearching = false
        stopSearchProgressTimer()
        pendingSearchKey = nil
        bufferedSearchResults = []
        isSearchResultFlushScheduled = false
        expandedBookName = nil
        searchResults = []
        rebuildRows()
        tableView.reloadData()
        updateBackground()
    }

    private func currentSearchMode(from searchBar: UISearchBar? = nil) -> String {
        let searchBar = searchBar ?? activeSearchBar ?? navigationItem.searchController?.searchBar
        return searchBar?.selectedScopeButtonIndex == 1 ? "filename" : "fulltext"
    }

    private func runSearch(query: String, mode: String, recordHistory: Bool) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            store.cancelSearch()
            showSearchHistory()
            return
        }
        let effectiveQuery = SearchText.normalizedQuery(cleaned)
        guard !effectiveQuery.isEmpty else {
            store.cancelSearch()
            showSearchHistory()
            return
        }
        let key = SearchCacheKey(query: effectiveQuery, mode: mode)
        if pendingSearchKey != key {
            store.cancelSearch()
        }
        bufferedSearchResults = []
        isSearchResultFlushScheduled = false
        submittedSearchQuery = effectiveQuery
        submittedSearchMode = mode
        isShowingSearchResults = true
        isShowingSearchHistory = false
        expandedBookName = nil

        if let cached = searchResultCache[key] {
            pendingSearchKey = nil
            isSearching = false
            stopSearchProgressTimer()
            searchResults = cached
            searchResultNameSet = Set(cached.map(\.bookName))
        } else {
            pendingSearchKey = key
            isSearching = true
            searchProgress = nil
            searchResults = []
            searchResultNameSet = []
        }
        if store.searchMode != mode {
            store.setSearchMode(mode)
        }
        if recordHistory {
            store.addSearchHistory(cleaned)
        }
        rebuildRows()
        tableView.reloadData()
        updateBackground()

        guard searchResultCache[key] == nil else { return }

        store.search(query: effectiveQuery, mode: mode, progress: { [weak self] progressValue in
            guard let self, self.pendingSearchKey == key else { return }
            self.searchProgress = progressValue
            self.updateBackground()
        }, onResult: { [weak self] result in
            guard let self, self.pendingSearchKey == key else { return }
            self.enqueueSearchResult(result, for: key)
        }) { [weak self] results in
            guard let self, self.pendingSearchKey == key else { return }
            self.pendingSearchKey = nil
            self.isSearching = false
            self.stopSearchProgressTimer()
            self.bufferedSearchResults = []
            self.isSearchResultFlushScheduled = false
            self.searchResultCache[key] = results
            self.searchResults = results
            self.searchResultNameSet = Set(results.map(\.bookName))
            self.rebuildRows()
            self.tableView.reloadData()
            self.updateBackground()
        }
    }

    private func cancelVisibleSearchWork() {
        guard isSearching || pendingSearchKey != nil else { return }
        store.cancelSearch()
        pendingSearchKey = nil
        isSearching = false
        stopSearchProgressTimer()
        bufferedSearchResults = []
        isSearchResultFlushScheduled = false
        updateBackground()
    }

    private func enqueueSearchResult(_ result: SearchResult, for key: SearchCacheKey) {
        guard searchResultNameSet.insert(result.bookName).inserted else { return }
        bufferedSearchResults.append(result)
        guard !isSearchResultFlushScheduled else { return }
        isSearchResultFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.flushSearchResults(for: key)
        }
    }

    private func flushSearchResults(for key: SearchCacheKey) {
        guard pendingSearchKey == key else {
            bufferedSearchResults = []
            isSearchResultFlushScheduled = false
            return
        }

        let chunkSize = 160
        let count = min(bufferedSearchResults.count, chunkSize)
        let newResults = Array(bufferedSearchResults.prefix(count))
        bufferedSearchResults.removeFirst(count)
        isSearchResultFlushScheduled = false
        guard !newResults.isEmpty else { return }

        let start = rows.count
        searchResults.append(contentsOf: newResults)
        rows.append(contentsOf: newResults.map { .searchResult($0, query: submittedSearchQuery) })
        let indexPaths = (start..<rows.count).map { IndexPath(row: $0, section: 0) }
        UIView.performWithoutAnimation {
            tableView.performBatchUpdates {
                tableView.insertRows(at: indexPaths, with: .none)
            }
        }
        updateBackground()

        if !bufferedSearchResults.isEmpty {
            isSearchResultFlushScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                self?.flushSearchResults(for: key)
            }
        }
    }

    private func loadSnippetIfNeeded(for result: SearchResult, query: String, at indexPath: IndexPath) {
        guard submittedSearchMode == "fulltext" else { return }
        guard result.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let key = SearchSnippetCacheKey(query: query, bookName: result.bookName)
        if let cached = snippetCache[key] {
            updateSnippet(cached, for: result.bookName, query: query, at: indexPath)
            return
        }
        guard pendingSnippetRequests.insert(key).inserted else { return }
        store.searchSnippet(bookName: result.bookName, query: query) { [weak self] snippet in
            guard let self else { return }
            self.pendingSnippetRequests.remove(key)
            let cleaned = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            self.snippetCache[key] = cleaned
            self.updateSnippet(cleaned, for: result.bookName, query: query, at: indexPath)
        }
    }

    private func updateSnippet(_ snippet: String, for bookName: String, query: String, at originalIndexPath: IndexPath) {
        guard isShowingSearchResults, submittedSearchQuery == query else { return }
        guard let resultIndex = searchResults.firstIndex(where: { $0.bookName == bookName }) else { return }
        let current = searchResults[resultIndex]
        guard current.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let updated = SearchResult(bookName: current.bookName, snippet: snippet)
        searchResults[resultIndex] = updated
        if resultIndex < rows.count {
            rows[resultIndex] = .searchResult(updated, query: query)
        }
        let cacheKey = SearchCacheKey(query: query, mode: submittedSearchMode)
        if var cachedResults = searchResultCache[cacheKey],
           let cachedIndex = cachedResults.firstIndex(where: { $0.bookName == bookName }) {
            cachedResults[cachedIndex] = updated
            searchResultCache[cacheKey] = cachedResults
        }
        let currentIndexPath = IndexPath(row: resultIndex, section: 0)
        guard tableView.indexPathsForVisibleRows?.contains(currentIndexPath) == true else { return }
        UIView.performWithoutAnimation {
            tableView.reloadRows(at: [currentIndexPath], with: .none)
        }
    }

    private func confirm(title: String, message: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in action() })
        present(alert, animated: true)
    }
}

final class SearchResultCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let snippetLabel = UILabel()
    private let stackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        snippetLabel.attributedText = nil
        snippetLabel.isHidden = false
    }

    private func configureView() {
        backgroundColor = .readerBackground
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .readerPressed
        multipleSelectionBackgroundView = UIView()
        multipleSelectionBackgroundView?.backgroundColor = .clear
        contentView.backgroundColor = .readerBackground

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .readerText
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true

        snippetLabel.font = .systemFont(ofSize: 14)
        snippetLabel.textColor = .readerSecondary
        snippetLabel.numberOfLines = 0
        snippetLabel.adjustsFontForContentSizeCategory = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 5
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(snippetLabel)

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }

    func configure(result: SearchResult, query: String) {
        titleLabel.attributedText = Self.highlighted(
            result.bookName,
            query: query,
            baseFont: .systemFont(ofSize: 16, weight: .semibold),
            baseColor: .readerText
        )
        let snippet = result.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        snippetLabel.isHidden = snippet.isEmpty
        snippetLabel.attributedText = Self.highlighted(
            snippet,
            query: query,
            baseFont: .systemFont(ofSize: 14),
            baseColor: .readerSecondary
        )
    }

    private static func highlighted(
        _ text: String,
        query: String,
        baseFont: UIFont,
        baseColor: UIColor
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ]
        )
        let terms = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return attributed }

        let nsText = text as NSString
        for term in terms {
            var searchRange = NSRange(location: 0, length: nsText.length)
            while searchRange.length > 0 {
                let match = nsText.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                )
                guard match.location != NSNotFound else { break }
                attributed.addAttributes(
                    [
                        .font: UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold),
                        .foregroundColor: UIColor.readerHighlight
                    ],
                    range: match
                )
                let nextLocation = match.location + max(match.length, 1)
                guard nextLocation < nsText.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
            }
        }
        return attributed
    }
}

final class BookNameCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let infoButton = UIButton(type: .system)
    private var onInfoTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onInfoTapped = nil
        infoButton.isHidden = false
        infoButton.isEnabled = true
        infoButton.isUserInteractionEnabled = true
        contentView.alpha = 1
    }

    private func configureView() {
        backgroundColor = .readerBackground
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .readerPressed
        multipleSelectionBackgroundView = UIView()
        multipleSelectionBackgroundView?.backgroundColor = .clear
        contentView.backgroundColor = .readerBackground

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .readerText
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true

        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)

        contentView.addSubview(titleLabel)
        contentView.addSubview(infoButton)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: infoButton.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            infoButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            infoButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 34),
            infoButton.heightAnchor.constraint(equalToConstant: 34),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    func configure(
        title: String,
        hasInfo: Bool,
        isExpanded: Bool,
        showsInfoButton: Bool,
        onInfoTapped: @escaping () -> Void
    ) {
        titleLabel.text = title
        infoButton.isHidden = !showsInfoButton
        infoButton.isEnabled = hasInfo && showsInfoButton
        infoButton.isUserInteractionEnabled = hasInfo && showsInfoButton
        infoButton.tintColor = hasInfo ? .readerAction : .readerSecondary
        infoButton.backgroundColor = hasInfo && isExpanded ? UIColor.white.withAlphaComponent(0.14) : .clear
        infoButton.layer.cornerRadius = 17
        self.onInfoTapped = onInfoTapped
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        infoButton.isHidden = editing
        clearEditingBackgrounds()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clearEditingBackgrounds()
    }

    private func clearEditingBackgrounds() {
        clearEditingBackgrounds(in: self)
    }

    private func clearEditingBackgrounds(in view: UIView) {
        for subview in view.subviews {
            if String(describing: type(of: subview)).contains("Editing") {
                subview.backgroundColor = .clear
                subview.subviews.forEach { $0.backgroundColor = .clear }
            }
            clearEditingBackgrounds(in: subview)
        }
    }

    @objc private func infoTapped() {
        onInfoTapped?()
    }
}

final class SearchHistoryCell: UITableViewCell {
    func configure(query: String, pinned: Bool) {
        backgroundColor = .readerBackground
        contentView.backgroundColor = .readerBackground
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .readerPressed
        multipleSelectionBackgroundView = UIView()
        multipleSelectionBackgroundView?.backgroundColor = .clear

        var content = UIListContentConfiguration.cell()
        content.image = UIImage(systemName: pinned ? "pin.fill" : "clock.arrow.circlepath")
        content.text = query
        content.textProperties.color = .readerText
        content.imageProperties.tintColor = pinned ? .readerAction : .readerSecondary
        contentConfiguration = content
        accessoryType = .none
    }
}

final class BookInfoTableViewCell: UITableViewCell {
    private let panelView = UIView()
    private let stackView = UIStackView()
    private let tagView = TagWrapView()
    private let summaryLabel = UILabel()
    private let emptyLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .readerBackground
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .readerPressed
        multipleSelectionBackgroundView = UIView()
        multipleSelectionBackgroundView?.backgroundColor = .clear
        contentView.backgroundColor = .readerBackground

        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.backgroundColor = .readerPanel

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10

        summaryLabel.font = .systemFont(ofSize: 14)
        summaryLabel.textColor = .readerText
        summaryLabel.numberOfLines = 0

        emptyLabel.text = "暂无简介信息"
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .readerSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        contentView.addSubview(panelView)
        panelView.addSubview(stackView)
        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: contentView.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with book: Book) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if book.hasInfo {
            let tags = book.tags
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .filter { $0.hasPrefix("#") }
                .map { String($0.dropFirst()) }

            if !tags.isEmpty {
                tagView.tags = tags
                stackView.addArrangedSubview(tagView)
            }

            if !book.summary.isEmpty {
                summaryLabel.text = book.summary
                stackView.addArrangedSubview(summaryLabel)
            }

            if tags.isEmpty && book.summary.isEmpty {
                stackView.addArrangedSubview(emptyLabel)
            }
        } else {
            stackView.addArrangedSubview(emptyLabel)
        }
    }
}

final class TagWrapView: UIView {
    var tags: [String] = [] {
        didSet {
            rebuildLabels()
        }
    }

    private var labels: [UILabel] = []
    private let horizontalSpacing: CGFloat = 8
    private let verticalSpacing: CGFloat = 8

    private func rebuildLabels() {
        labels.forEach { $0.removeFromSuperview() }
        labels = tags.map { tag in
            let label = PaddingLabel()
            label.text = tag
            label.font = .systemFont(ofSize: 12)
            label.textColor = .readerText
            label.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            label.layer.cornerRadius = 11
            label.layer.masksToBounds = true
            addSubview(label)
            return label
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        let maxWidth = bounds.width

        for label in labels {
            let size = label.intrinsicContentSize
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            label.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 40
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for label in labels {
            let size = label.intrinsicContentSize
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: UIView.noIntrinsicMetric, height: y + lineHeight)
    }
}

final class PaddingLabel: UILabel {
    private let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

final class ReaderTextView: UITextView {}

final class ReaderViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    private let store: ReaderStore
    private static let richTextCharacterLimit = 180_000
    private static let manualWrapCharacterLimit = 260_000
    private var bookName: String
    private let textView = ReaderTextView()
    private var titleEditField: UITextField?
    private var loadedContent = ""
    private var displayedContent = ""
    private var isEditingBook = false
    private var isSavingEdit = false
    private var isRepairingEncoding = false
    private var undoButton: UIBarButtonItem?
    private var redoButton: UIBarButtonItem?

    init(store: ReaderStore, bookName: String) {
        self.store = store
        self.bookName = bookName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = bookName
        view.backgroundColor = .readerBackground
        navigationItem.largeTitleDisplayMode = .never
        configureTextView()
        configureNavigationItems()
        loadContent()
        NotificationCenter.default.addObserver(self, selector: #selector(editingTextDidChange), name: UITextView.textDidChangeNotification, object: textView)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    private func configureTextView() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.delegate = self
        textView.alwaysBounceVertical = true
        textView.contentInsetAdjustmentBehavior = .never
        textView.backgroundColor = .readerBackground
        textView.textColor = .readerText
        textView.font = .preferredFont(forTextStyle: .body).withSize(CGFloat(store.fontSize))
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 18, bottom: 40, right: 18)
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureNavigationItems() {
        if isEditingBook {
            let undoItem = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: self, action: #selector(undoEdit))
            let redoItem = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: self, action: #selector(redoEdit))
            undoButton = undoItem
            redoButton = redoItem
            navigationItem.leftBarButtonItems = [undoItem, redoItem]
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: isSavingEdit ? "保存中" : "退出编辑", style: .done, target: self, action: #selector(finishEditingBook))
            navigationItem.rightBarButtonItem?.isEnabled = !isSavingEdit
            updateEditingControls()
            return
        }

        undoButton = nil
        redoButton = nil
        navigationItem.leftBarButtonItems = nil
        navigationItem.titleView = nil
        title = bookName
        let isFavorite = store.favorites.contains(bookName)
        let isInTrash = store.trashNames.contains(bookName)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: [
                UIAction(title: "分享", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    self?.shareBook()
                },
                UIAction(title: "编辑", image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
                    self?.beginEditingBook()
                },
                UIAction(title: isFavorite ? "取消收藏" : "收藏", image: UIImage(systemName: isFavorite ? "star.slash" : "star")) { [weak self] _ in
                    self?.toggleFavorite()
                },
                UIAction(title: isInTrash ? "恢复" : "删除", image: UIImage(systemName: isInTrash ? "arrow.counterclockwise" : "trash")) { [weak self] _ in
                    self?.deleteOrRestore()
                },
                UIAction(title: "纠正编码", image: UIImage(systemName: "textformat.abc")) { [weak self] _ in
                    self?.confirmRepairEncoding()
                }
            ])
        )
        navigationItem.rightBarButtonItem?.tintColor = .readerAction
    }

    private func loadContent() {
        applyReaderText("加载中...")
        DispatchQueue.global(qos: .userInitiated).async {
            let content = self.store.content(for: self.bookName)
            let displayText = Self.displayTextForReading(content)
            DispatchQueue.main.async {
                self.loadedContent = content
                self.displayedContent = displayText
                self.applyReaderText(displayText)
                self.textView.layoutIfNeeded()
                let topOffset = CGPoint(x: 0, y: -self.textView.adjustedContentInset.top)
                self.textView.setContentOffset(topOffset, animated: false)
            }
        }
    }

    private static func displayTextForReading(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "（本文为空）" }
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard normalized.count <= manualWrapCharacterLimit else { return normalized }
        var output = ""
        output.reserveCapacity(normalized.count + normalized.count / 48)
        normalized.enumerateLines { rawLine, _ in
            for line in readingLines(from: rawLine) {
                if !output.isEmpty {
                    output.append("\n")
                }
                output.append(line)
            }
        }
        return output.isEmpty ? "（本文为空）" : output
    }

    private static func readingLines(from rawLine: String) -> [String] {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return [""] }
        guard line.count > 120 else { return [line] }

        let sentenceBreaks = Set("。！？!?；;…")
        let clauseBreaks = Set("，,、：:）)】】」』")
        let preferredLength = 72
        let hardLimit = 96

        func wrap(_ text: String, preferred: Int, hard: Int, breakSet: Set<Character>?) -> [String] {
            guard text.count > hard else { return [text] }
            var chunks: [String] = []
            var current = ""
            for character in text {
                current.append(character)
                let shouldBreak =
                    current.count >= hard ||
                    (current.count >= preferred && (breakSet?.contains(character) ?? false))
                if shouldBreak {
                    let chunk = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !chunk.isEmpty {
                        chunks.append(chunk)
                    }
                    current = ""
                }
            }
            let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                chunks.append(tail)
            }
            return chunks
        }

        let sentenceChunks = wrap(line, preferred: preferredLength, hard: hardLimit, breakSet: sentenceBreaks)
        var result: [String] = []
        for sentenceChunk in sentenceChunks {
            let clauseChunks = wrap(sentenceChunk, preferred: 44, hard: 56, breakSet: clauseBreaks)
            for clauseChunk in clauseChunks {
                result.append(contentsOf: wrap(clauseChunk, preferred: 28, hard: 36, breakSet: nil))
            }
        }
        return result.isEmpty ? [line] : result
    }

    private func applyReaderText(_ content: String) {
        let fontSize = CGFloat(store.fontSize)
        let font = UIFont.preferredFont(forTextStyle: .body).withSize(fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.8
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.lineBreakMode = .byCharWrapping
        textView.font = font
        textView.textColor = .readerText
        guard content.count <= Self.richTextCharacterLimit else {
            textView.text = content
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: UIColor.readerText,
                .paragraphStyle: paragraphStyle
            ]
            return
        }
        textView.attributedText = NSAttributedString(
            string: content,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.readerText,
                .paragraphStyle: paragraphStyle
            ]
        )
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: UIColor.readerText,
            .paragraphStyle: paragraphStyle
        ]
    }

    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        let textLength = (textView.text as NSString).length
        var actions: [UIMenuElement] = []

        if textLength > 0, textView.selectedRange.length < textLength {
            actions.append(UIAction(title: "全选", image: UIImage(systemName: "textformat")) { [weak textView] _ in
                textView?.selectAll(nil)
            })
        }

        if textView.selectedRange.length > 0 || range.length > 0 {
            actions.append(UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { [weak textView] _ in
                textView?.copy(nil)
            })
        }

        return UIMenu(children: actions)
    }

    @objc private func toggleFavorite() {
        store.toggleFavorite(bookName)
        configureNavigationItems()
    }

    private func confirmRepairEncoding() {
        guard !isRepairingEncoding else { return }
        let alert = UIAlertController(
            title: "纠正编码",
            message: "将尝试修复当前文章正文中的乱码，并永久写入数据库。确认继续？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确认", style: .default) { [weak self] _ in
            self?.repairEncoding()
        })
        present(alert, animated: true)
    }

    private func repairEncoding() {
        guard !isRepairingEncoding else { return }
        isRepairingEncoding = true
        store.repairBookEncoding(name: bookName) { [weak self] result in
            guard let self else { return }
            self.isRepairingEncoding = false
            switch result {
            case .success:
                self.loadContent()
            case .failure(let error):
                self.showError("纠正编码失败：\(error)")
            }
        }
    }

    private func beginEditingBook() {
        guard !isEditingBook else { return }
        isEditingBook = true
        applyReaderText(loadedContent)
        let accessoryView = editingInputAccessoryView()
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 260, height: 34))
        field.text = bookName
        field.textColor = .readerText
        field.tintColor = .readerAction
        field.textAlignment = .center
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .done
        field.delegate = self
        field.backgroundColor = UIColor.readerControl.withAlphaComponent(0.7)
        field.layer.cornerRadius = 8
        field.layer.masksToBounds = true
        field.inputAccessoryView = accessoryView
        titleEditField = field
        navigationItem.titleView = field
        textView.isEditable = true
        textView.inputAccessoryView = accessoryView
        textView.reloadInputViews()
        textView.becomeFirstResponder()
        configureNavigationItems()
    }

    @objc private func finishEditingBook() {
        guard isEditingBook, !isSavingEdit else { return }
        view.endEditing(true)
        let newTitle = (titleEditField?.text ?? bookName).trimmingCharacters(in: .whitespacesAndNewlines)
        let newContent = textView.text ?? ""
        isSavingEdit = true
        configureNavigationItems()
        store.updateBook(originalName: bookName, title: newTitle, content: newContent) { [weak self] result in
            guard let self else { return }
            self.isSavingEdit = false
            switch result {
            case .success(let savedName):
                self.bookName = savedName
                self.loadedContent = newContent
                self.isEditingBook = false
                self.textView.isEditable = false
                self.textView.inputAccessoryView = nil
                self.textView.reloadInputViews()
                let displayText = Self.displayTextForReading(newContent)
                self.displayedContent = displayText
                self.applyReaderText(displayText)
                self.titleEditField = nil
                self.navigationItem.titleView = nil
                self.title = savedName
                self.configureNavigationItems()
            case .failure(let error):
                self.configureNavigationItems()
                self.showError("保存失败：\(error)")
            }
        }
    }

    @objc private func undoEdit() {
        textView.undoManager?.undo()
        updateEditingControls()
    }

    @objc private func redoEdit() {
        textView.undoManager?.redo()
        updateEditingControls()
    }

    @objc private func editingTextDidChange() {
        updateEditingControls()
    }

    @objc private func dismissEditingKeyboard() {
        view.endEditing(true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func updateEditingControls() {
        guard isEditingBook else { return }
        undoButton?.isEnabled = textView.undoManager?.canUndo == true
        redoButton?.isEnabled = textView.undoManager?.canRedo == true
    }

    private func editingInputAccessoryView() -> UIView {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem.flexibleSpace(),
            UIBarButtonItem(title: "收起键盘", style: .plain, target: self, action: #selector(dismissEditingKeyboard))
        ]
        toolbar.tintColor = .readerAction
        return toolbar
    }

    @objc private func shareBook() {
        guard let url = store.exportURL(for: bookName) else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(controller, animated: true)
    }

    @objc private func deleteOrRestore() {
        if store.trashNames.contains(bookName) {
            store.restoreFromTrash(bookName)
            navigationController?.popViewController(animated: true)
            return
        }

        let alert = UIAlertController(title: "移到最近删除", message: "将“\(bookName)”移到最近删除？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.store.moveToTrash(self.bookName)
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

final class SettingsViewController: UITableViewController {
    private enum Row {
        case stateWarning
        case fontSize
        case searchPresets
        case recent
        case trash
    }

    private let store: ReaderStore
    private var rows: [[Row]] {
        var dataRows: [Row] = []
        if store.stateWarning != nil {
            dataRows.append(.stateWarning)
        }
        dataRows.append(contentsOf: [.recent, .trash])
        return [
            [.fontSize],
            [.searchPresets],
            dataRows
        ]
    }

    init(store: ReaderStore) {
        self.store = store
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = .readerBackground
        tableView.backgroundColor = .readerBackground
        tableView.separatorColor = .readerSeparator
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "阅读"
        case 1:
            return "搜索"
        case 2:
            return "数据"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.section][indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        cell.backgroundColor = .readerPanel
        cell.accessoryView = nil
        cell.accessoryType = .none

        var content = UIListContentConfiguration.valueCell()
        content.textProperties.color = .readerText
        content.secondaryTextProperties.color = .readerSecondary
        content.secondaryTextProperties.numberOfLines = 0
        switch row {
        case .stateWarning:
            content.image = UIImage(systemName: "exclamationmark.triangle")
            content.text = "本地状态未持久化"
            content.secondaryText = store.stateWarning
        case .fontSize:
            content.image = UIImage(systemName: "textformat.size")
            content.text = "字体大小"
            content.secondaryText = "\(store.fontSize)"
            cell.accessoryView = stepper(value: Double(store.fontSize), min: 14, max: 28, step: 1, action: #selector(fontSizeChanged(_:)))
        case .searchPresets:
            content.image = UIImage(systemName: "magnifyingglass.circle")
            content.text = "常用搜索词"
            content.secondaryText = "\(store.searchPresets.count)"
            cell.accessoryType = .disclosureIndicator
        case .recent:
            content.image = UIImage(systemName: "clock")
            content.text = "最近阅读"
            content.secondaryText = "\(store.recentBooks.count)"
            cell.accessoryType = .disclosureIndicator
        case .trash:
            content.image = UIImage(systemName: "trash")
            content.text = "最近删除"
            content.secondaryText = "\(store.trashBooks.count)"
            cell.accessoryType = .disclosureIndicator
        }

        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.section][indexPath.row] {
        case .searchPresets:
            navigationController?.pushViewController(SearchPresetListViewController(store: store), animated: true)
        case .recent:
            navigationController?.pushViewController(BookListViewController(kind: .recent, store: store), animated: true)
        case .trash:
            navigationController?.pushViewController(BookListViewController(kind: .trash, store: store), animated: true)
        case .fontSize, .stateWarning:
            break
        }
    }

    private func stepper(value: Double, min: Double, max: Double, step: Double, action: Selector) -> UIStepper {
        let stepper = UIStepper()
        stepper.minimumValue = min
        stepper.maximumValue = max
        stepper.stepValue = step
        stepper.value = value
        stepper.addTarget(self, action: action, for: .valueChanged)
        return stepper
    }

    @objc private func fontSizeChanged(_ sender: UIStepper) {
        store.setFontSize(Int(sender.value))
        tableView.reloadData()
    }
}

final class SearchPresetListViewController: UITableViewController {
    private let store: ReaderStore
    private var isBuildingPreset = false

    init(store: ReaderStore) {
        self.store = store
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "常用搜索词"
        view.backgroundColor = .readerBackground
        tableView.backgroundColor = .readerBackground
        tableView.separatorColor = .readerSeparator
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PresetCell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addPreset)
        )
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.searchPresets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let preset = store.searchPresets[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PresetCell", for: indexPath)
        cell.backgroundColor = .readerBackground
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = .readerPressed

        var content = UIListContentConfiguration.subtitleCell()
        content.image = UIImage(systemName: "magnifyingglass")
        content.text = preset.query
        content.secondaryText = "已缓存"
        content.textProperties.color = .readerText
        content.secondaryTextProperties.color = .readerSecondary
        content.imageProperties.tintColor = .readerAction
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        let query = store.searchPresets[indexPath.row].query
        store.removeSearchPreset(query)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    @objc private func addPreset() {
        guard !isBuildingPreset else { return }
        let alert = UIAlertController(title: "添加常用搜索词", message: "添加后会立即检索并缓存结果。", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "搜索词"
            field.textColor = .readerText
            field.tintColor = .readerAction
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "添加", style: .default) { [weak self, weak alert] _ in
            let query = alert?.textFields?.first?.text ?? ""
            self?.buildPreset(query)
        })
        present(alert, animated: true)
    }

    private func buildPreset(_ query: String) {
        let cleaned = SearchText.normalizedQuery(query)
        guard !cleaned.isEmpty else { return }
        isBuildingPreset = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        title = "缓存中..."
        store.addSearchPreset(cleaned, progress: { [weak self] progress in
            guard let self else { return }
            self.title = "缓存中，已处理 \(progress.searched) \(progress.unit)"
        }) { [weak self] result in
            guard let self else { return }
            self.isBuildingPreset = false
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            self.title = "常用搜索词"
            switch result {
            case .success:
                self.tableView.reloadData()
            case .failure(let error):
                let alert = UIAlertController(title: "缓存失败", message: "\(error)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}

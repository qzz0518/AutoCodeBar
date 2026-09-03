#!/usr/bin/env swift

import Darwin
import Foundation

private let localeIDs = ["zh-Hans", "en"]
private let requiredTables: Set<String> = [
    "Core.strings",
    "InfoPlist.strings",
    "Localizable.strings",
]

// MARK: - printf signatures

private struct ArgumentUse: Hashable {
    let index: Int
    let type: String
}

private struct FormatSignature {
    var argumentUses: [ArgumentUse: Int] = [:]
    var conversionCount = 0
    var placeholders: [String] = []
    var problems: [String] = []

    var description: String {
        let arguments = argumentUses
            .sorted {
                if $0.key.index != $1.key.index {
                    return $0.key.index < $1.key.index
                }
                return $0.key.type < $1.key.type
            }
            .map { use, count in
                let suffix = count == 1 ? "" : " x\(count)"
                return "#\(use.index) \(use.type)\(suffix)"
            }
            .joined(separator: ", ")
        let raw = placeholders.isEmpty ? "none" : placeholders.joined(separator: ", ")
        return "\(conversionCount) placeholder(s); arguments [\(arguments)]; raw [\(raw)]"
    }
}

// Captures, in order: conversion position, width, width star, width-star
// position, precision, precision star, precision-star position, length and
// conversion. A literal %% is handled before this expression is evaluated.
private let printfExpression = try! NSRegularExpression(
    pattern: #"%(?:(\d+)\$)?[-+#0']*(?:(\d+)|(\*)(?:(\d+)\$)?)?(?:\.(?:(\d+)|(\*)(?:(\d+)\$)?))?(hh|h|ll|l|j|z|t|L|q)?([@diuoxXfFeEgGaAcCsSpnDUO])"#
)

private func capture(
    _ index: Int,
    from match: NSTextCheckingResult,
    in string: NSString
) -> String? {
    let range = match.range(at: index)
    guard range.location != NSNotFound else { return nil }
    return string.substring(with: range)
}

private func integerWidth(for length: String) -> String {
    switch length {
    case "hh": return "char"
    case "h": return "short"
    case "l": return "long"
    case "ll", "q": return "long-long"
    case "j": return "intmax"
    case "z": return "size"
    case "t": return "ptrdiff"
    default: return "int"
    }
}

private func argumentType(length: String, conversion: Character) -> String {
    switch conversion {
    case "@":
        return "object"
    case "d", "i":
        return "signed-\(integerWidth(for: length))"
    case "u", "o", "x", "X":
        return "unsigned-\(integerWidth(for: length))"
    case "f", "F", "e", "E", "g", "G", "a", "A":
        return length == "L" ? "long-double" : "double"
    case "c":
        return length == "l" ? "wide-character" : "character"
    case "C":
        return "wide-character"
    case "s":
        return length == "l" ? "wide-string" : "c-string"
    case "S":
        return "wide-string"
    case "p":
        return "pointer"
    case "n":
        return "count-pointer-\(integerWidth(for: length))"
    case "D":
        return "signed-long"
    case "U", "O":
        return "unsigned-long"
    default:
        return "unknown-\(conversion)"
    }
}

private func parseFormatSignature(_ value: String) -> FormatSignature {
    let nsValue = value as NSString
    var signature = FormatSignature()
    var searchOffset = 0
    var nextSequentialIndex = 1
    var sawSequential = false
    var sawPositional = false

    func resolvedIndex(_ explicitPosition: String?, rawPlaceholder: String) -> Int? {
        if let explicitPosition {
            sawPositional = true
            guard let position = Int(explicitPosition), position > 0 else {
                signature.problems.append("invalid argument position in \(rawPlaceholder)")
                return nil
            }
            return position
        }

        sawSequential = true
        defer { nextSequentialIndex += 1 }
        return nextSequentialIndex
    }

    func recordArgument(
        explicitPosition: String?,
        type: String,
        rawPlaceholder: String
    ) {
        guard let index = resolvedIndex(explicitPosition, rawPlaceholder: rawPlaceholder) else {
            return
        }
        let use = ArgumentUse(index: index, type: type)
        signature.argumentUses[use, default: 0] += 1
    }

    while searchOffset < nsValue.length {
        let remainingRange = NSRange(
            location: searchOffset,
            length: nsValue.length - searchOffset
        )
        let percentRange = nsValue.range(of: "%", options: [], range: remainingRange)
        guard percentRange.location != NSNotFound else { break }

        let percentOffset = percentRange.location
        if percentOffset + 1 < nsValue.length,
           nsValue.substring(with: NSRange(location: percentOffset + 1, length: 1)) == "%" {
            searchOffset = percentOffset + 2
            continue
        }

        let candidateRange = NSRange(
            location: percentOffset,
            length: nsValue.length - percentOffset
        )
        guard let match = printfExpression.firstMatch(
            in: value,
            options: [.anchored],
            range: candidateRange
        ) else {
            // A plain percent sign is valid in a non-format string. Only
            // syntactically complete printf conversions are signatures here.
            searchOffset = percentOffset + 1
            continue
        }

        let rawPlaceholder = nsValue.substring(with: match.range)
        signature.placeholders.append(rawPlaceholder)

        if capture(3, from: match, in: nsValue) != nil {
            recordArgument(
                explicitPosition: capture(4, from: match, in: nsValue),
                type: "signed-int",
                rawPlaceholder: rawPlaceholder
            )
        }
        if capture(6, from: match, in: nsValue) != nil {
            recordArgument(
                explicitPosition: capture(7, from: match, in: nsValue),
                type: "signed-int",
                rawPlaceholder: rawPlaceholder
            )
        }

        let length = capture(8, from: match, in: nsValue) ?? ""
        let conversionString = capture(9, from: match, in: nsValue)!
        let conversion = conversionString.first!
        recordArgument(
            explicitPosition: capture(1, from: match, in: nsValue),
            type: argumentType(length: length, conversion: conversion),
            rawPlaceholder: rawPlaceholder
        )
        signature.conversionCount += 1
        searchOffset = match.range.location + match.range.length
    }

    if sawSequential && sawPositional {
        signature.problems.append(
            "mixes positional and non-positional arguments; use one style consistently"
        )
    }

    let usesByIndex = Dictionary(grouping: signature.argumentUses.keys, by: \.index)
    for (index, uses) in usesByIndex.sorted(by: { $0.key < $1.key }) {
        let types = Set(uses.map(\.type))
        if types.count > 1 {
            signature.problems.append(
                "argument #\(index) is used with incompatible types: "
                    + types.sorted().joined(separator: ", ")
            )
        }
    }

    return signature
}

// MARK: - .strings tables

private func relativeStringsFiles(in directory: URL) throws -> Set<String> {
    guard let enumerator = FileManager.default.enumerator(atPath: directory.path) else {
        throw NSError(
            domain: "LocalizationCheck",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "cannot enumerate \(directory.path)"]
        )
    }

    var files: Set<String> = []
    for case let relativePath as String in enumerator {
        guard !relativePath
            .split(separator: "/")
            .contains(where: { $0.hasPrefix(".") }) else {
            continue
        }
        let fileURL = directory.appendingPathComponent(relativePath)
        guard fileURL.pathExtension == "strings" else { continue }
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }
        files.insert(relativePath)
    }
    return files
}

private func loadStrings(
    at url: URL,
    label: String,
    errors: inout [String]
) -> [String: String]? {
    do {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.openStep
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        )
        guard let dictionary = propertyList as? [String: Any] else {
            errors.append("[\(label)] top level must be a string dictionary")
            return nil
        }

        var strings: [String: String] = [:]
        for key in dictionary.keys.sorted() {
            guard let value = dictionary[key] as? String else {
                errors.append("[\(label)] key \(key.debugDescription) has a non-string value")
                continue
            }
            strings[key] = value
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("[\(label)] key \(key.debugDescription) has an empty value")
            }
        }
        return strings
    } catch {
        errors.append("[\(label)] cannot parse .strings file: \(error.localizedDescription)")
        return nil
    }
}

private func writeErrors(_ errors: [String]) {
    let lines = ["Localization validation failed with \(errors.count) error(s):"]
        + errors.map { "error: \($0)" }
    let output = lines.joined(separator: "\n") + "\n"
    FileHandle.standardError.write(Data(output.utf8))
}

// MARK: - Swift sources

/// One string literal found in a Swift file, with everything the checks below
/// need to decide whether it is user-facing copy.
private struct SourceLiteral {
    let file: URL
    let line: Int
    /// The literal's own text, still escaped exactly as it appears in the source.
    let raw: String
    /// The code immediately before the opening quote, comments already removed.
    let precedingCode: String
    /// True while the literal sits inside a `#if DEBUG` block.
    let inDebugBlock: Bool
    /// The nearest enclosing declaration listed in `nonInterfaceDeclarations`.
    let enclosingAllowedDeclaration: String?
}

/// Declarations whose Chinese literals are matching data for the extractor, not
/// copy the user ever reads. Everything else with a Han character has to go
/// through `L10n`.
private let nonInterfaceDeclarations: Set<String> = [
    "contextMarkers",
    "defaultKeywords",
    "leadMarkers",
    "legacyDefaultKeywords",
    "unitWords",
    "yearSuffix",
]

/// Walks a Swift file once, tracking comments, string literals (single line,
/// multi-line and raw), interpolation and `#if DEBUG` nesting. A regular
/// expression cannot do this: `//` inside a literal is not a comment, and a
/// quote inside a comment does not open one.
private func literals(in file: URL, errors: inout [String]) -> [SourceLiteral] {
    guard let source = try? String(contentsOf: file, encoding: .utf8) else {
        errors.append("cannot read source: \(file.path)")
        return []
    }

    var found: [SourceLiteral] = []
    let characters = Array(source)
    var index = 0
    var line = 1
    /// Code seen since the last statement break, comments stripped. Only the
    /// tail matters, so it is reset often enough to stay short.
    var codeTail = ""
    var blockCommentDepth = 0
    /// One entry per open `#if`; true when any arm of it tests DEBUG.
    var conditionalStack: [Bool] = []
    var bracketDepth = 0
    /// The allowlisted declaration currently being scanned, and where it ends:
    /// at a bracket depth for an array literal, at a line for a scalar.
    var activeDeclaration: (name: String, bracketDepth: Int?, line: Int?)?

    func appendCode(_ character: Character) {
        codeTail.append(character)
        if codeTail.count > 240 {
            codeTail.removeFirst(codeTail.count - 240)
        }
    }

    func readLiteral(delimiterPounds: Int, isMultiline: Bool, startLine: Int) -> String {
        // The opening delimiter has already been consumed.
        var text = ""
        let closing = isMultiline ? "\"\"\"" : "\""
        while index < characters.count {
            let character = characters[index]
            if character == "\\" {
                var lookahead = index + 1
                var pounds = 0
                while lookahead < characters.count, characters[lookahead] == "#", pounds < delimiterPounds {
                    pounds += 1
                    lookahead += 1
                }
                if pounds == delimiterPounds {
                    if lookahead < characters.count, characters[lookahead] == "(" {
                        // Interpolation: skip the balanced parentheses whole. Any
                        // nested literal belongs to the expression, not this one.
                        var depth = 1
                        index = lookahead + 1
                        while index < characters.count, depth > 0 {
                            if characters[index] == "(" { depth += 1 }
                            if characters[index] == ")" { depth -= 1 }
                            if characters[index] == "\n" { line += 1 }
                            index += 1
                        }
                        text.append("\\()")
                        continue
                    }
                    // A plain escape: copy it so the scan never mistakes an
                    // escaped quote for the end of the literal.
                    if lookahead < characters.count {
                        text.append("\\")
                        text.append(characters[lookahead])
                        if characters[lookahead] == "\n" { line += 1 }
                        index = lookahead + 1
                        continue
                    }
                }
            }
            if character == "\"" {
                var candidate = ""
                var lookahead = index
                while lookahead < characters.count, candidate.count < closing.count {
                    candidate.append(characters[lookahead])
                    lookahead += 1
                }
                if candidate == closing {
                    var pounds = 0
                    while lookahead < characters.count, characters[lookahead] == "#", pounds < delimiterPounds {
                        pounds += 1
                        lookahead += 1
                    }
                    if pounds == delimiterPounds {
                        index = lookahead
                        return text
                    }
                }
            }
            if character == "\n" {
                line += 1
                if !isMultiline {
                    // An unterminated literal means the scanner lost sync; stop
                    // rather than swallow the rest of the file.
                    index += 1
                    return text
                }
            }
            text.append(character)
            index += 1
        }
        return text
    }

    while index < characters.count {
        let character = characters[index]

        if blockCommentDepth > 0 {
            if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                blockCommentDepth += 1
                index += 2
                continue
            }
            if character == "*", index + 1 < characters.count, characters[index + 1] == "/" {
                blockCommentDepth -= 1
                index += 2
                continue
            }
            if character == "\n" { line += 1 }
            index += 1
            continue
        }

        if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
            while index < characters.count, characters[index] != "\n" { index += 1 }
            continue
        }
        if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
            blockCommentDepth = 1
            index += 2
            continue
        }

        // Raw string delimiters: any run of # directly before a quote.
        if character == "#" {
            var pounds = 0
            var lookahead = index
            while lookahead < characters.count, characters[lookahead] == "#" {
                pounds += 1
                lookahead += 1
            }
            if lookahead < characters.count, characters[lookahead] == "\"" {
                let startLine = line
                var isMultiline = false
                var cursor = lookahead + 1
                if cursor + 1 < characters.count,
                   characters[cursor] == "\"", characters[cursor + 1] == "\"" {
                    isMultiline = true
                    cursor += 2
                }
                let preceding = codeTail
                index = cursor
                let text = readLiteral(
                    delimiterPounds: pounds,
                    isMultiline: isMultiline,
                    startLine: startLine
                )
                found.append(SourceLiteral(
                    file: file,
                    line: startLine,
                    raw: text,
                    precedingCode: preceding,
                    inDebugBlock: conditionalStack.contains(true),
                    enclosingAllowedDeclaration: activeDeclaration?.name
                ))
                codeTail = ""
                continue
            }
        }

        if character == "\"" {
            let startLine = line
            var isMultiline = false
            var cursor = index + 1
            if cursor + 1 < characters.count,
               characters[cursor] == "\"", characters[cursor + 1] == "\"" {
                isMultiline = true
                cursor += 2
            }
            let preceding = codeTail
            index = cursor
            let text = readLiteral(
                delimiterPounds: 0,
                isMultiline: isMultiline,
                startLine: startLine
            )
            found.append(SourceLiteral(
                file: file,
                line: startLine,
                raw: text,
                precedingCode: preceding,
                inDebugBlock: conditionalStack.contains(true),
                enclosingAllowedDeclaration: activeDeclaration?.name
            ))
            codeTail = ""
            continue
        }

        if character == "\n" {
            line += 1
            // A declaration that was not an array literal ends with its line.
            if let active = activeDeclaration, active.line != nil {
                activeDeclaration = nil
            }
            codeTail = ""
            index += 1
            continue
        }

        if character == "[" { bracketDepth += 1 }
        if character == "]" {
            bracketDepth -= 1
            if let active = activeDeclaration, active.bracketDepth == bracketDepth {
                activeDeclaration = nil
            }
        }

        appendCode(character)

        // Compiler directives change which branch of the file is live.
        if codeTail.hasSuffix("#if ") || codeTail.hasSuffix("#if(") {
            var lookahead = index + 1
            var condition = ""
            while lookahead < characters.count, characters[lookahead] != "\n" {
                condition.append(characters[lookahead])
                lookahead += 1
            }
            conditionalStack.append(condition.contains("DEBUG"))
        }
        if codeTail.hasSuffix("#endif"), !conditionalStack.isEmpty {
            conditionalStack.removeLast()
        }

        // Remember the name of an allowlisted declaration so its contents can
        // be skipped. The scan ends at the closing bracket of an array literal,
        // or at the end of the line for a scalar.
        if character == "=", activeDeclaration == nil {
            let words = codeTail
                .dropLast()
                .split(whereSeparator: { " \t:[]<>,?!.".contains($0) })
                .map(String.init)
            var name: String?
            if let binding = words.firstIndex(where: { $0 == "let" || $0 == "var" }),
               binding + 1 < words.count {
                name = words[binding + 1]
            }
            if let name, nonInterfaceDeclarations.contains(name) {
                var lookahead = index + 1
                while lookahead < characters.count,
                      characters[lookahead] == " " || characters[lookahead] == "\t" {
                    lookahead += 1
                }
                if lookahead < characters.count, characters[lookahead] == "[" {
                    activeDeclaration = (name: name, bracketDepth: bracketDepth, line: nil)
                } else {
                    activeDeclaration = (name: name, bracketDepth: nil, line: line)
                }
            }
        }

        index += 1
    }

    return found
}

private let hanExpression = try! NSRegularExpression(pattern: #"\p{Han}"#)

private func containsHan(_ value: String) -> Bool {
    let range = NSRange(location: 0, length: (value as NSString).length)
    return hanExpression.firstMatch(in: value, range: range) != nil
}

/// True when the literal is the first argument of a call that either localizes
/// it or deliberately opts out of localization.
private func isWrapped(_ literal: SourceLiteral) -> Bool {
    let trimmed = literal.precedingCode.trimmingCharacters(in: .whitespacesAndNewlines)
    let wrappers = [
        "L10n.text(",
        "L10n.format(",
        "Text(verbatim:",
        "accessibilityLabel(Text(verbatim:",
    ]
    return wrappers.contains { trimmed.hasSuffix($0) }
}

/// Decodes a source literal the way the compiler would, so its text can be
/// matched against a .strings key.
private func decodeSwiftLiteral(_ raw: String, label: String, errors: inout [String]) -> String? {
    let snippet = "\"value\" = \"\(raw)\";"
    guard let data = snippet.data(using: .utf8),
          let plist = try? PropertyListSerialization.propertyList(
              from: data,
              options: [],
              format: nil
          ) as? [String: String],
          let value = plist["value"] else {
        errors.append("cannot decode string literal in \(label): \(raw)")
        return nil
    }
    return value
}

// MARK: - Run

let scriptURL = URL(fileURLWithPath: #filePath).standardizedFileURL
let repositoryRoot = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let localizationsRoot = repositoryRoot
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("Localizations", isDirectory: true)

var errors: [String] = []
var tablesByLocale: [String: Set<String>] = [:]

for localeID in localeIDs {
    let directory = localizationsRoot
        .appendingPathComponent("\(localeID).lproj", isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        errors.append("missing localization directory: \(directory.path)")
        tablesByLocale[localeID] = []
        continue
    }

    do {
        let tables = try relativeStringsFiles(in: directory)
        tablesByLocale[localeID] = tables
        if tables.isEmpty {
            errors.append("[\(localeID)] contains no .strings tables")
        }
        for table in requiredTables.subtracting(tables).sorted() {
            errors.append("[\(localeID)] missing required table: \(table)")
        }
    } catch {
        errors.append("[\(localeID)] \(error.localizedDescription)")
        tablesByLocale[localeID] = []
    }
}

let zhTables = tablesByLocale["zh-Hans"] ?? []
let enTables = tablesByLocale["en"] ?? []

for table in zhTables.subtracting(enTables).sorted() {
    errors.append("[en] missing table present in zh-Hans: \(table)")
}
for table in enTables.subtracting(zhTables).sorted() {
    errors.append("[zh-Hans] missing table present in en: \(table)")
}

let allTables = zhTables.union(enTables).sorted()
var checkedKeyCount = 0

for table in allTables {
    var stringsByLocale: [String: [String: String]] = [:]

    for localeID in localeIDs where tablesByLocale[localeID]?.contains(table) == true {
        let url = localizationsRoot
            .appendingPathComponent("\(localeID).lproj", isDirectory: true)
            .appendingPathComponent(table)
        if let strings = loadStrings(
            at: url,
            label: "\(localeID)/\(table)",
            errors: &errors
        ) {
            stringsByLocale[localeID] = strings
        }
    }

    guard let zhStrings = stringsByLocale["zh-Hans"],
          let enStrings = stringsByLocale["en"] else {
        continue
    }

    let zhKeys = Set(zhStrings.keys)
    let enKeys = Set(enStrings.keys)
    for key in zhKeys.subtracting(enKeys).sorted() {
        errors.append("[en/\(table)] missing key \(key.debugDescription)")
    }
    for key in enKeys.subtracting(zhKeys).sorted() {
        errors.append("[zh-Hans/\(table)] missing key \(key.debugDescription)")
    }

    for key in zhKeys.intersection(enKeys).sorted() {
        checkedKeyCount += 1
        if containsHan(enStrings[key]!) {
            errors.append(
                "[en/\(table)] key \(key.debugDescription) still contains Han characters"
            )
        }
        // Chinese is the source language, so its value has to be the key. A
        // drifted value would silently ship two different Chinese strings.
        if table != "InfoPlist.strings", zhStrings[key]! != key {
            errors.append(
                "[zh-Hans/\(table)] key \(key.debugDescription) has a value that differs "
                    + "from the key: \(zhStrings[key]!.debugDescription)"
            )
        }
        let zhSignature = parseFormatSignature(zhStrings[key]!)
        let enSignature = parseFormatSignature(enStrings[key]!)

        for problem in zhSignature.problems {
            errors.append("[zh-Hans/\(table)] key \(key.debugDescription): \(problem)")
        }
        for problem in enSignature.problems {
            errors.append("[en/\(table)] key \(key.debugDescription): \(problem)")
        }

        if zhSignature.conversionCount != enSignature.conversionCount
            || zhSignature.argumentUses != enSignature.argumentUses {
            errors.append(
                "[\(table)] key \(key.debugDescription) has incompatible printf placeholders\n"
                    + "  zh-Hans: \(zhSignature.description)\n"
                    + "  en:      \(enSignature.description)"
            )
        }
    }
}

let sourceChecks = [
    (target: "AutoCodeBar", table: "Localizable.strings"),
    (target: "AutoCodeBarCore", table: "Core.strings"),
]

var scannedFileCount = 0
var unwrappedCount = 0

for check in sourceChecks {
    let sources = repositoryRoot
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(check.target, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: sources,
        includingPropertiesForKeys: [.isRegularFileKey]
    ) else {
        errors.append("cannot enumerate sources: \(sources.path)")
        continue
    }

    let englishTableURL = localizationsRoot
        .appendingPathComponent("en.lproj", isDirectory: true)
        .appendingPathComponent(check.table)
    let englishTable: [String: String]?
    if FileManager.default.fileExists(atPath: englishTableURL.path) {
        englishTable = loadStrings(
            at: englishTableURL,
            label: "en/\(check.table)",
            errors: &errors
        )
    } else {
        englishTable = nil
    }

    for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
        scannedFileCount += 1
        let found = literals(in: fileURL, errors: &errors)
        for literal in found {
            let location = "\(fileURL.lastPathComponent):\(literal.line)"
            if isWrapped(literal) {
                guard let englishTable,
                      literal.precedingCode.hasSuffix("L10n.text(")
                        || literal.precedingCode.hasSuffix("L10n.format(") else {
                    continue
                }
                guard let key = decodeSwiftLiteral(
                    literal.raw,
                    label: location,
                    errors: &errors
                ) else {
                    continue
                }
                if englishTable[key] == nil {
                    errors.append(
                        "[en/\(check.table)] missing key \(key.debugDescription) used at \(location)"
                    )
                }
                continue
            }

            guard containsHan(literal.raw) else { continue }
            if literal.inDebugBlock { continue }
            if literal.enclosingAllowedDeclaration != nil { continue }
            unwrappedCount += 1
            errors.append(
                "\(location): Chinese literal is not localized: "
                    + literal.raw.debugDescription
            )
        }
    }
}

if !errors.isEmpty {
    writeErrors(errors)
    exit(EXIT_FAILURE)
}

print(
    "Localization validation passed: \(allTables.count) table(s), "
        + "\(checkedKeyCount) shared key(s), languages \(localeIDs.joined(separator: ", "))."
)
print(
    "Scanned \(scannedFileCount) Swift file(s); \(unwrappedCount) unwrapped Chinese literal(s)."
)

#if SQLITE_ENABLE_FTS5
// Import C SQLite functions
#if GRDBCIPHER
import SQLCipher
#elseif SWIFT_PACKAGE
import GRDBSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

/// A type that implements a custom tokenizer for the ``FTS5`` full-text engine.
///
/// See [FTS5 Tokenizers](https://github.com/groue/GRDB.swift/blob/master/Documentation/FTS5Tokenizers.md)
/// for more information.
public protocol FTS5CustomTokenizer: FTS5Tokenizer {
    /// The name of the tokenizer.
    ///
    /// The name should uniquely identify the tokenizer: don't use a built-in
    /// name such as `ascii`, `porter` or `unicode61`.
    static var name: String { get }
    
    /// Creates a custom tokenizer.
    ///
    /// The arguments parameter is an array of String built from the CREATE
    /// VIRTUAL TABLE statement. In the example below, the arguments will
    /// be `["arg1", "arg2"]`.
    ///
    ///     CREATE VIRTUAL TABLE document USING fts5(
    ///         tokenize='custom arg1 arg2'
    ///     )
    ///
    /// - parameter db: A Database connection
    /// - parameter arguments: An array of string arguments
    init(db: Database, arguments: [String]) throws
}

extension FTS5CustomTokenizer {
    
    /// Creates an FTS5 tokenizer descriptor.
    ///
    ///     class MyTokenizer : FTS5CustomTokenizer { ... }
    ///
    ///     try db.create(virtualTable: "book", using: FTS5()) { t in
    ///         let tokenizer = MyTokenizer.tokenizerDescriptor(arguments: ["unicode61", "remove_diacritics", "0"])
    ///         t.tokenizer = tokenizer
    ///     }
    public static func tokenizerDescriptor(arguments: [String] = []) -> FTS5TokenizerDescriptor {
        FTS5TokenizerDescriptor(components: [name] + arguments)
    }
}

extension Database {
    
    // MARK: - FTS5
    
    private class FTS5TokenizerConstructor {
        let db: Database
        let constructor: (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> CInt
        
        init(
            db: Database,
            constructor: @escaping (Database, [String], UnsafeMutablePointer<OpaquePointer?>?) -> CInt)
        {
            self.db = db
            self.constructor = constructor
        }
    }
    
    /// Add a custom FTS5 tokenizer.
    ///
    ///     class MyTokenizer : FTS5CustomTokenizer { ... }
    ///     db.add(tokenizer: MyTokenizer.self)
    public func add(tokenizer: (some FTS5CustomTokenizer).Type) {
        let api = FTS5.api(self)
        
        // Swift won't let the @convention(c) xCreate() function below create
        // an instance of the generic Tokenizer type.
        //
        // We thus hide the generic Tokenizer type inside a neutral type:
        // FTS5TokenizerConstructor
        let constructor = FTS5TokenizerConstructor(
            db: self,
            constructor: { (db, arguments, tokenizerHandle) in
                guard let tokenizerHandle else {
                    return SQLITE_ERROR
                }
                do {
                    let tokenizer = try tokenizer.init(db: db, arguments: arguments)
                    
                    // Tokenizer must remain alive until xDeleteTokenizer()
                    // is called, as the xDelete member of xTokenizer
                    let tokenizerPointer = OpaquePointer(Unmanaged.passRetained(tokenizer).toOpaque())
                    
                    tokenizerHandle.pointee = tokenizerPointer
                    return SQLITE_OK
                } catch let error as DatabaseError {
                    return error.extendedResultCode.rawValue
                } catch {
                    return SQLITE_ERROR
                }
            })
        
        // Constructor must remain alive until deleteConstructor() is
        // called, as the last argument of the xCreateTokenizer() function.
        let constructorPointer = Unmanaged.passRetained(constructor).toOpaque()
        
        func deleteConstructor(constructorPointer: UnsafeMutableRawPointer?) {
            guard let constructorPointer else { return }
            Unmanaged<AnyObject>.fromOpaque(constructorPointer).release()
        }
        
        func xCreateTokenizer(
            constructorPointer: UnsafeMutableRawPointer?,
            azArg: UnsafeMutablePointer<UnsafePointer<Int8>?>?,
            nArg: CInt,
            tokenizerHandle: UnsafeMutablePointer<OpaquePointer?>?)
        -> CInt
        {
            guard let constructorPointer else {
                return SQLITE_ERROR
            }
            let constructor = Unmanaged<FTS5TokenizerConstructor>.fromOpaque(constructorPointer).takeUnretainedValue()
            var arguments: [String] = []
            if let azArg {
                for i in 0..<Int(nArg) {
                    if let cstr = azArg[i] {
                        arguments.append(String(cString: cstr))
                    }
                }
            }
            return constructor.constructor(constructor.db, arguments, tokenizerHandle)
        }
        
        func xDeleteTokenizer(tokenizerPointer: OpaquePointer?) {
            guard let tokenizerPointer else { return }
            Unmanaged<AnyObject>.fromOpaque(UnsafeMutableRawPointer(tokenizerPointer)).release()
        }
        
        func xTokenize(
            tokenizerPointer: OpaquePointer?,
            context: UnsafeMutableRawPointer?,
            flags: CInt,
            pText: UnsafePointer<CChar>?,
            nText: CInt,
            // swiftlint:disable:next line_length
            tokenCallback: (@convention(c) (UnsafeMutableRawPointer?, CInt, UnsafePointer<CChar>?, CInt, CInt, CInt) -> CInt)?)
        -> CInt
        {
            guard let tokenizerPointer else {
                return SQLITE_ERROR
            }
            let object = Unmanaged<AnyObject>
                .fromOpaque(UnsafeMutableRawPointer(tokenizerPointer))
                .takeUnretainedValue()
            guard let tokenizer = object as? any FTS5Tokenizer else {
                return SQLITE_ERROR
            }
            return tokenizer.tokenize(
                context: context,
                tokenization: FTS5Tokenization(rawValue: flags),
                pText: pText,
                nText: nText,
                tokenCallback: tokenCallback!)
        }
        
        var xTokenizer = fts5_tokenizer(xCreate: xCreateTokenizer, xDelete: xDeleteTokenizer, xTokenize: xTokenize)
        let code = withUnsafeMutablePointer(to: &xTokenizer) { xTokenizerPointer in
            api.pointee.xCreateTokenizer(
                UnsafeMutablePointer(mutating: api),
                tokenizer.name,
                constructorPointer,
                xTokenizerPointer,
                deleteConstructor)
        }
        guard code == SQLITE_OK else {
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError(DatabaseError(resultCode: code, message: lastErrorMessage))
        }
    }
}
#endif

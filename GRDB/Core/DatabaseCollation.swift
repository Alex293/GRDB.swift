// Import C SQLite functions
#if GRDBCIPHER
import SQLCipher
#elseif SWIFT_PACKAGE
import GRDBSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// `DatabaseCollation` is a custom string comparison function used by SQLite.
///
/// See also ``Database/CollationName``.
/// 
/// Related SQLite documentation: <https://www.sqlite.org/datatype3.html#collating_sequences>
///
/// ## Topics
///
/// ### Creating a Custom Collation
///
/// - ``init(_:function:)``
/// - ``name``
///
/// ### Built-in Collations
///
/// - ``caseInsensitiveCompare``
/// - ``localizedCaseInsensitiveCompare``
/// - ``localizedCompare``
/// - ``localizedStandardCompare``
/// - ``unicodeCompare``
public final class DatabaseCollation: Identifiable, Sendable {
    /// The identifier of an SQLite collation.
    ///
    /// SQLite identifies collations by their name (case insensitive).
    public struct ID: Hashable {
        var name: String
        
        // Collation equality is based on the sqlite3_strnicmp SQLite function.
        // (see https://www.sqlite.org/c3ref/create_collation.html). Computing
        // a hash value that honors the Swift Hashable contract (value equality
        // implies hash equality) is thus non trivial. But it's not that
        // important, since this hashValue is only used when one adds
        // or removes a collation from a database connection.
        public func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
        
        /// Two collations are equal if they share the same name (case insensitive)
        public static func == (lhs: Self, rhs: Self) -> Bool {
            // See <https://www.sqlite.org/c3ref/create_collation.html>
            return sqlite3_stricmp(lhs.name, rhs.name) == 0
        }
    }
    
    /// The identifier of the collation.
    public var id: ID { ID(name: name) }
    
    /// The name of the collation.
    public let name: String
    let function: @Sendable (CInt, UnsafeRawPointer?, CInt, UnsafeRawPointer?) -> ComparisonResult
    
    /// Creates a collation.
    ///
    /// For example:
    ///
    /// ```swift
    /// let collation = DatabaseCollation("localized_standard") { (string1, string2) in
    ///     return (string1 as NSString).localizedStandardCompare(string2)
    /// }
    /// db.add(collation: collation)
    /// try db.execute(sql: "CREATE TABLE file (name TEXT COLLATE localized_standard")
    /// ```
    ///
    /// - parameters:
    ///     - name: The collation name.
    ///     - function: A function that compares two strings.
    public init(_ name: String, function: @escaping @Sendable (String, String) -> ComparisonResult) {
        self.name = name
        self.function = { (length1, buffer1, length2, buffer2) in
            // Buffers are not C strings: they do not end with \0.
            let string1 = String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer1.unsafelyUnwrapped),
                length: Int(length1),
                encoding: .utf8,
                freeWhenDone: false)!
            let string2 = String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer2.unsafelyUnwrapped),
                length: Int(length2),
                encoding: .utf8,
                freeWhenDone: false)!
            return function(string1, string2)
        }
    }
}

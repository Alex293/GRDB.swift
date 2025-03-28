import XCTest
import GRDB

private struct CustomValueType : DatabaseValueConvertible {
    var databaseValue: DatabaseValue { "CustomValueType".databaseValue }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CustomValueType? {
        guard let string = String.fromDatabaseValue(dbValue), string == "CustomValueType" else {
            return nil
        }
        return CustomValueType()
    }
}

class DatabaseFunctionTests: GRDBTestCase {
    
    // MARK: - Default functions
    
    func testDefaultFunctions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            
            // Those functions are automatically added to all connections.
            // See Database.setupDefaultFunctions()
            
            let capitalize = DatabaseFunction.capitalize
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT \(capitalize.name)('jérÔME')"), "Jérôme")
            
            let lowercase = DatabaseFunction.lowercase
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT \(lowercase.name)('jérÔME')"), "jérôme")
            
            let uppercase = DatabaseFunction.uppercase
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT \(uppercase.name)('jérÔME')"), "JÉRÔME")
            
            // Locale-dependent tests. Are they fragile?
            
            let localizedCapitalize = DatabaseFunction.localizedCapitalize
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT \(localizedCapitalize.name)('jérÔME')"), "Jérôme")
            
            let localizedLowercase = DatabaseFunction.localizedLowercase
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT \(localizedLowercase.name)('jérÔME')"), "jérôme")
            
            let localizedUppercase = DatabaseFunction.localizedUppercase
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT \(localizedUppercase.name)('jérÔME')"), "JÉRÔME")
        }
    }

    // MARK: - Return values

    func testFunctionReturningNull() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return nil
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try DatabaseValue.fetchOne(db, sql: "SELECT f()")!.isNull)
        }
    }

    func testFunctionReturningInt64() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return Int64(1)
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try Int64.fetchOne(db, sql: "SELECT f()")!, Int64(1))
        }
    }

    func testFunctionReturningDouble() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return 1e100
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try Double.fetchOne(db, sql: "SELECT f()")!, 1e100)
        }
    }

    func testFunctionReturningString() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return "foo"
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT f()")!, "foo")
        }
    }

    func testFunctionReturningData() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return "foo".data(using: .utf8)
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try Data.fetchOne(db, sql: "SELECT f()")!, "foo".data(using: .utf8))
        }
    }

    func testFunctionReturningCustomValueType() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return CustomValueType()
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try CustomValueType.fetchOne(db, sql: "SELECT f()") != nil)
        }
    }

    // MARK: - Argument values
    
    func testFunctionArgumentNil() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            return dbValues[0].isNull
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try Bool.fetchOne(db, sql: "SELECT f(NULL)")!)
            XCTAssertFalse(try Bool.fetchOne(db, sql: "SELECT f(1)")!)
            XCTAssertFalse(try Bool.fetchOne(db, sql: "SELECT f(1.1)")!)
            XCTAssertFalse(try Bool.fetchOne(db, sql: "SELECT f('foo')")!)
            XCTAssertFalse(try Bool.fetchOne(db, sql: "SELECT f(?)", arguments: ["foo".data(using: .utf8)])!)
            XCTAssertFalse(try Bool.fetchOne(db, sql: "SELECT f(?)", arguments: [Data()])!)
        }
    }

    func testFunctionArgumentInt64() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            return Int64.fromDatabaseValue(dbValues[0])
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try Int64.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            XCTAssertEqual(try Int64.fetchOne(db, sql: "SELECT f(1)")!, 1)
            XCTAssertEqual(try Int64.fetchOne(db, sql: "SELECT f(1.1)")!, 1)
        }
    }

    func testFunctionArgumentDouble() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            return Double.fromDatabaseValue(dbValues[0])
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try Double.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            XCTAssertEqual(try Double.fetchOne(db, sql: "SELECT f(1)")!, 1.0)
            XCTAssertEqual(try Double.fetchOne(db, sql: "SELECT f(1.1)")!, 1.1)
        }
    }

    func testFunctionArgumentString() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            return String.fromDatabaseValue(dbValues[0])
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try String.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT f('foo')")!, "foo")
        }
    }

    func testFunctionArgumentBlob() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            return Data.fromDatabaseValue(dbValues[0])
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try Data.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            XCTAssertEqual(try Data.fetchOne(db, sql: "SELECT f(?)", arguments: ["foo".data(using: .utf8)])!, "foo".data(using: .utf8))
            XCTAssertEqual(try Data.fetchOne(db, sql: "SELECT f(?)", arguments: [Data()])!, Data())
        }
    }

    func testFunctionArgumentCustomValueType() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            return CustomValueType.fromDatabaseValue(dbValues[0])
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertTrue(try CustomValueType.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            XCTAssertTrue(try CustomValueType.fetchOne(db, sql: "SELECT f('CustomValueType')") != nil)
        }
    }

    // MARK: - Argument count
    
    func testFunctionWithoutArgument() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return "foo"
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT f()")!, "foo")
            do {
                try db.execute(sql: "SELECT f(1)")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f(1)")
                XCTAssertEqual(error.description, "SQLite error 1: wrong number of arguments to function f() - while executing `SELECT f(1)`")
            }
        }
    }

    func testFunctionOfOneArgument() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { (dbValues: [DatabaseValue]) in
            String.fromDatabaseValue(dbValues[0]).map { $0.uppercased() }
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT f(?)", arguments: ["Roué"])!, "ROUÉ")
            XCTAssertTrue(try String.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f()")
                XCTAssertEqual(error.description, "SQLite error 1: wrong number of arguments to function f() - while executing `SELECT f()`")
            }
        }
    }

    func testFunctionOfTwoArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 2) { dbValues in
            let ints = dbValues.compactMap { Int.fromDatabaseValue($0) }
            return ints.reduce(0, +)
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT f(1, 2)")!, 3)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f()")
                XCTAssertEqual(error.description, "SQLite error 1: wrong number of arguments to function f() - while executing `SELECT f()`")
            }
        }
    }

    func testVariadicFunction() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f") { dbValues in
            return dbValues.count
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT f()")!, 0)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT f(1)")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT f(1, 1)")!, 2)
        }
    }

    // MARK: - Errors

    func testFunctionThrowingDatabaseErrorWithMessage() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f") { dbValues in
            throw DatabaseError(message: "custom error message")
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testFunctionThrowingDatabaseErrorWithCode() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f") { dbValues in
            throw DatabaseError(resultCode: ResultCode(rawValue: 123))
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "unknown error")
            }
        }
    }

    func testFunctionThrowingDatabaseErrorWithMessageAndCode() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f") { dbValues in
            throw DatabaseError(resultCode: ResultCode(rawValue: 123), message: "custom error message")
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testFunctionThrowingCustomError() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f") { dbValues in
            throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                #if canImport(ObjectiveC) // non-Darwin platforms bridge NSError differently and do not set the message the same
                XCTAssertTrue(error.message!.contains("CustomErrorDomain"))
                XCTAssertTrue(error.message!.contains("123"))
                XCTAssertTrue(error.message!.contains("custom error message"))
                #endif
            }
        }
    }

    // MARK: - Misc

    func testFunctionsAreClosures() throws {
        let dbQueue = try makeDatabaseQueue()
        let mutex = Mutex(123)
        let fn = DatabaseFunction("f", argumentCount: 0) { dbValues in
            return mutex.load()
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            mutex.store(321)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT f()")!, 321)
        }
    }
}

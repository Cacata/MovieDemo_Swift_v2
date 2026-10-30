import Foundation
import SQLite3

actor SQLiteFavoriteRepository: FavoriteRepository {
    private let databaseHandle: SQLiteHandle
    private var database: OpaquePointer { databaseHandle.pointer }

    init(databaseURL: URL) throws {
        var openedDatabase: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &openedDatabase) == SQLITE_OK,
              let openedDatabase else {
            throw SQLiteFavoriteError.openFailed
        }
        databaseHandle = SQLiteHandle(pointer: openedDatabase)
        let createTable = """
        CREATE TABLE IF NOT EXISTS favorite_movies (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            overview TEXT NOT NULL,
            poster_path TEXT,
            backdrop_path TEXT,
            release_date TEXT,
            vote_average REAL NOT NULL
        );
        """
        guard sqlite3_exec(openedDatabase, createTable, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteFavoriteError.statementFailed
        }
    }

    func favorites() async throws -> [Movie] {
        let query = """
        SELECT id, title, overview, poster_path, backdrop_path, release_date, vote_average
        FROM favorite_movies ORDER BY title COLLATE NOCASE ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteFavoriteError.statementFailed
        }
        defer { sqlite3_finalize(statement) }

        var movies: [Movie] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            movies.append(
                Movie(
                    id: Int(sqlite3_column_int64(statement, 0)),
                    title: string(statement, column: 1) ?? "",
                    overview: string(statement, column: 2) ?? "",
                    posterPath: string(statement, column: 3),
                    backdropPath: string(statement, column: 4),
                    releaseDate: string(statement, column: 5),
                    voteAverage: sqlite3_column_double(statement, 6)
                )
            )
        }
        return movies
    }

    func isFavorite(movieID: Int) async throws -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT 1 FROM favorite_movies WHERE id = ? LIMIT 1;", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteFavoriteError.statementFailed
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, sqlite3_int64(movieID))
        return sqlite3_step(statement) == SQLITE_ROW
    }

    func saveFavorite(_ movie: Movie) async throws {
        let sql = """
        INSERT OR REPLACE INTO favorite_movies
        (id, title, overview, poster_path, backdrop_path, release_date, vote_average)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteFavoriteError.statementFailed
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, sqlite3_int64(movie.id))
        bind(movie.title, to: statement, column: 2)
        bind(movie.overview, to: statement, column: 3)
        bind(movie.posterPath, to: statement, column: 4)
        bind(movie.backdropPath, to: statement, column: 5)
        bind(movie.releaseDate, to: statement, column: 6)
        sqlite3_bind_double(statement, 7, movie.voteAverage)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteFavoriteError.statementFailed }
    }

    func removeFavorite(movieID: Int) async throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "DELETE FROM favorite_movies WHERE id = ?;", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteFavoriteError.statementFailed
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, sqlite3_int64(movieID))
        guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteFavoriteError.statementFailed }
    }

    private func string(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    private func bind(_ value: String?, to statement: OpaquePointer?, column: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, column)
            return
        }
        sqlite3_bind_text(statement, column, value, -1, SQLITE_TRANSIENT)
    }
}

private final class SQLiteHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        sqlite3_close(pointer)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteFavoriteError: Error {
    case openFailed
    case statementFailed
}

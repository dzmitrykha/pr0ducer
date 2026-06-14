import Foundation
import GRDB
import Shared
import SQLiteData

public enum DatabaseBootstrap {
  /// Opens the App Group database with foreign keys enabled and runs migrations.
  public static func persistent(url: URL = AppGroup.databaseURL) throws -> any DatabaseWriter {
    let configuration = makeConfiguration()
    let database = try DatabasePool(path: url.path(), configuration: configuration)
    try migrate(database)
    return database
  }

  /// In-memory database for tests and degraded-mode fallback.
  public static func inMemory() throws -> any DatabaseWriter {
    let configuration = makeConfiguration()
    let database = try DatabaseQueue(configuration: configuration)
    try migrate(database)
    return database
  }

  static func makeConfiguration() -> Configuration {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    return configuration
  }

  static func migrate(_ database: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    #if DEBUG
      migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("001_create_activities") { db in
      try #sql(
        """
        CREATE TABLE "activities" (
          "id" TEXT NOT NULL PRIMARY KEY,
          "startedAt" INTEGER NOT NULL,
          "endedAt" INTEGER,
          "createdAt" INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE INDEX "activities_startedAt_idx"
        ON "activities" ("startedAt")
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE INDEX "activities_in_progress_idx"
        ON "activities" ("endedAt")
        WHERE "endedAt" IS NULL
        """
      )
      .execute(db)
    }
    try migrator.migrate(database)
  }
}

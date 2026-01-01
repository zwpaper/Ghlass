import Foundation
import SQLite

class DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?
    private let notifications = Table("notifications")
    private let id = Expression<String>("id")
    private let lastUpdated = Expression<Double>("last_updated")

    private init() {
        do {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return
            }

            let dbPath = documentsURL.appendingPathComponent("ghlass.sqlite3").path
            db = try Connection(dbPath)
            createTable()
        } catch {
            print("Database initialization failed: \(error)")
        }
    }

    private func createTable() {
        guard let db = db else { return }

        do {
            try db.run(notifications.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(lastUpdated)
            })
        } catch {
            print("Failed to create table: \(error)")
        }
    }

    func markNotificationAsDone(notificationId: String, updatedAt: Date) {
        guard let db = db else { return }

        do {
            let timestamp = updatedAt.timeIntervalSince1970
            let insert = notifications.insert(or: .replace, id <- notificationId, lastUpdated <- timestamp)
            try db.run(insert)
        } catch {
            print("Failed to save notification state: \(error)")
        }
    }

    func shouldShowNotification(notificationId: String, currentUpdatedAt: Date) -> Bool {
        guard let db = db else { return true }

        do {
            let query = notifications.filter(id == notificationId)
            if let row = try db.pluck(query) {
                let savedTimestamp = row[lastUpdated]
                // If current update is newer than saved, show it.
                // If current update is older or equal to saved, hide it (it's handled).
                return currentUpdatedAt.timeIntervalSince1970 > savedTimestamp
            }
        } catch {
            print("Failed to check notification state: \(error)")
        }

        return true
    }
}
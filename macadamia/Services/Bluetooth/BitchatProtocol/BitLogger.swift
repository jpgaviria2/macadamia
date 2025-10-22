//
//  BitLogger.swift
//  macadamia
//
//  Simple BitLogger replacement for bitchat compatibility
//

import Foundation
import OSLog

// Simple BitLogger replacement using OSLog
public struct BitLogger {
    public static func info(_ message: String, category: String = "macadamia") {
        let logger = Logger(subsystem: "macadamia", category: category)
        logger.info("\(message)")
    }
    
    public static func debug(_ message: String, category: String = "macadamia") {
        let logger = Logger(subsystem: "macadamia", category: category)
        logger.debug("\(message)")
    }
    
    public static func warning(_ message: String, category: String = "macadamia") {
        let logger = Logger(subsystem: "macadamia", category: category)
        logger.warning("\(message)")
    }
    
    public static func error(_ message: String, category: String = "macadamia") {
        let logger = Logger(subsystem: "macadamia", category: category)
        logger.error("\(message)")
    }
}

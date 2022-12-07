//
//  Logger.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 12/7/22.
//

import Foundation

// Adapted from: https://youtu.be/Ao6jkaV_9Kc
class Log {
    static var logLevel: Level = .debug
    
    enum Level: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        fileprivate var prefix: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
    }
    
    struct Context {
        var file: String = #fileID
        var function: String = #function
        var line: Int = #line
        var description: String {
            return "\(file):\(line) -> \(function)"
        }
    }
    
    private static func handle(level: Level, str: Any?, shouldLogContext: Bool, context: Context) {
        var msg = "[\(level.prefix)]\t|"
        if shouldLogContext {
            msg += " \(context.description)\t|"
        }
        
        var _msg: String = " nil"
        if let str = str { _msg = " \(str)" }
        
        msg += _msg
        
        print(msg)
    }
    
    static func debug(_ msg: Any?, shouldLogContext: Bool = true, file: String = #fileID, fn: String = #function, line: Int = #line) {
#if DEBUG
        if logLevel.rawValue <= Level.debug.rawValue {
            Log.handle(level: .debug, str: msg, shouldLogContext: shouldLogContext, context: Context(file: file, function: fn, line: line))
        }
#endif
    }
    
    static func info(_ msg: Any?, shouldLogContext: Bool = true, file: String = #fileID, fn: String = #function, line: Int = #line) {
#if DEBUG
        if logLevel.rawValue <= Level.info.rawValue {
            Log.handle(level: .info, str: msg, shouldLogContext: shouldLogContext, context: Context(file: file, function: fn, line: line))
        }
#endif
    }
    
    static func warn(_ msg: Any?, shouldLogContext: Bool = true, file: String = #fileID, fn: String = #function, line: Int = #line) {
#if DEBUG
        if logLevel.rawValue <= Level.warning.rawValue {
            Log.handle(level: .warning, str: msg, shouldLogContext: shouldLogContext, context: Context(file: file, function: fn, line: line))
        }
#endif
    }
    
    static func error(_ msg: Any?, shouldLogContext: Bool = true, file: String = #fileID, fn: String = #function, line: Int = #line) {
#if DEBUG
        if logLevel.rawValue <= Level.error.rawValue {
            Log.handle(level: .error, str: msg, shouldLogContext: shouldLogContext, context: Context(file: file, function: fn, line: line))
        }
#endif
    }
    
    static func critical(_ msg: Any?, shouldLogContext: Bool = true, file: String = #fileID, fn: String = #function, line: Int = #line) {
#if DEBUG
        if logLevel.rawValue <= Level.error.rawValue {
            Log.handle(level: .critical, str: msg, shouldLogContext: shouldLogContext, context: Context(file: file, function: fn, line: line))
        }
#endif
    }
}

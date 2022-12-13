//
//  MBError.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 12/8/22.
//

import Foundation

enum DatabaseError: Error {
    case UserReferenceEmpty
}

enum BackendError: Error, LocalizedError {
    case ResponseEmpty
    case TaskIdEmpty
    case RegionDownloadError(String)
    case SongDownloadError
    case DecodingError
    case WriteToFileError
    
    public var errorDescription: String? {
        switch self {
        case .SongDownloadError:
            return "This song cannot be downloaded at the moment. Please try again later or try a different song!"
        case .ResponseEmpty:
            return "No response from the Server. Please try again later"
        case .TaskIdEmpty:
            return "No task Id found"
        case .RegionDownloadError(let id):
            return "Region \(id) cannot of be downloaded"
        case .DecodingError:
            return "There was an issue decoding. Please try again later"
        case .WriteToFileError:
            return "There was an issue saving audio. Please try again"
        }
    }
}

enum SetValueError: Error {
    case AudioNotFound
    case ValueNotUpdated
    case IllegalArgument
}

enum MBError: Error {
    case SongStillDownloading
    case RemoveError
}

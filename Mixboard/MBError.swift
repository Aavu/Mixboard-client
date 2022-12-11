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

enum BackendError: Error {
    case ResponseEmpty
    case TaskIdEmpty
    case RegionDownloadError(String)
    case SongDownloadError
    case DecodingError
    case WriteToFileError
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

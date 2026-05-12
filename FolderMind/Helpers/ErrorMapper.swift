import Foundation

struct ErrorMapper {
    static func userFriendlyError(from error: Error) -> String {
        let nsError = error as NSError
        
        // Cocoa Errors (File System)
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
                return "Permission denied. Please ensure FolderMind has 'Full Disk Access' in System Settings."
            case NSFileWriteOutOfSpaceError:
                return "Disk is full. Please free up some space and try again."
            case NSFileWriteFileExistsError:
                return "File already exists at destination. Check your rule settings."
            case NSFileNoSuchFileError:
                return "The source file was moved or deleted before it could be processed."
            case NSFileWriteInvalidFileNameError:
                return "The destination filename is invalid."
            default:
                break
            }
        }
        
        // POSIX Errors
        if nsError.domain == NSPOSIXErrorDomain {
            switch Int32(nsError.code) {
            case EACCES:
                return "Permission denied (EACCES). Check folder permissions."
            case ENOSPC:
                return "No space left on device (ENOSPC)."
            case EROFS:
                return "The volume is read-only."
            default:
                break
            }
        }

        return error.localizedDescription
    }
}

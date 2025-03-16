#import "XXDecryptor.h"
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>

// External function declaration for mremap_encrypted
extern int mremap_encrypted(void* addr, size_t len, uint32_t cryptid, uint32_t cputype, uint32_t cpusubtype);

@implementation XXDecryptor

#pragma mark - Public API

+ (BOOL)decryptBinary:(NSString *)sourcePath toPath:(NSString *)targetPath withLog:(void(^)(NSString *log))logCallback {
    // Use fixed output directory
    NSString *baseOutputDir = @"/private/var/mobile/Documents/Decrypt-output";
    
    // Prepare output directory and paths
    NSString *outputPath = [self prepareOutputPathForSource:sourcePath inBaseDir:baseOutputDir];
    
    NSLog(@"H3ck - Starting decryption process");
    NSLog(@"H3ck - Source path: %@", sourcePath);
    NSLog(@"H3ck - Target path: %@", outputPath);
    
    // Ensure target directory exists
    if (![self createDirectoryForPath:outputPath logCallback:logCallback]) {
        return NO;
    }
    
    // Process and decrypt binary to new location
    BOOL result = [self processAndSaveFileAtPath:sourcePath toPath:outputPath logCallback:logCallback];
    
    if (result) {
        NSString *successMsg = [NSString stringWithFormat:@"Decrypted binary saved to: %@", outputPath];
        NSLog(@"H3ck - %@", successMsg);
        if (logCallback) logCallback(successMsg);
        
        // Save metadata
        [self saveMetadataForDecryption:sourcePath outputPath:outputPath result:result];
    }
    
    NSLog(@"H3ck - Decryption process finished with result: %@", result ? @"SUCCESS" : @"FAILURE");
    return result;
}

+ (BOOL)isBinaryEncrypted:(NSString *)binaryPath withLog:(void(^)(NSString *log))logCallback {
    // Map the file into memory
    void *fileMap;
    size_t fileSize;
    int fd;
    
    if (![self mapFileIntoMemory:binaryPath fileMap:&fileMap fileSize:&fileSize fileDescriptor:&fd logCallback:logCallback]) {
        return NO;
    }
    
    // Process Mach-O header
    struct mach_header_64 *header = (struct mach_header_64 *)fileMap;
    if (![self validateMachOHeader:header logCallback:logCallback]) {
        munmap(fileMap, fileSize);
        close(fd);
        return NO;
    }
    
    // Check encryption status
    BOOL isEncrypted = NO;
    struct encryption_info_command_64 *encCmd = NULL;
    [self checkEncryptionStatus:header isEncrypted:&isEncrypted encryptionCommand:&encCmd logCallback:logCallback];
    
    // Cleanup
    munmap(fileMap, fileSize);
    close(fd);
    
    return isEncrypted;
}

#pragma mark - Path and Directory Management

+ (NSString *)prepareOutputPathForSource:(NSString *)sourcePath inBaseDir:(NSString *)baseOutputDir {
    // Get app name from source path
    NSString *appName = [[sourcePath lastPathComponent] stringByDeletingPathExtension];
    NSString *timestamp = [self getCurrentTimestampFormatted];
    
    // Create app-specific folder with timestamp
    NSString *appDir = [baseOutputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", appName, timestamp]];
    return [appDir stringByAppendingPathComponent:[sourcePath lastPathComponent]];
}

+ (NSString *)getCurrentTimestampFormatted {
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                        dateStyle:NSDateFormatterShortStyle
                                                        timeStyle:NSDateFormatterShortStyle];
    timestamp = [timestamp stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    timestamp = [timestamp stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    return timestamp;
}

+ (BOOL)createDirectoryForPath:(NSString *)path logCallback:(void(^)(NSString *log))logCallback {
    NSString *dirPath = [path stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:dirPath]) {
        NSError *error;
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSString *errorMsg = [NSString stringWithFormat:@"Failed to create directory: %@", error.localizedDescription];
            NSLog(@"H3ck - %@", errorMsg);
            if (logCallback) logCallback(errorMsg);
            return NO;
        }
    }
    return YES;
}

+ (void)saveMetadataForDecryption:(NSString *)sourcePath outputPath:(NSString *)outputPath result:(BOOL)result {
    NSString *appDir = [outputPath stringByDeletingLastPathComponent];
    NSString *infoPath = [appDir stringByAppendingPathComponent:@"info.txt"];
    NSString *timestamp = [self getCurrentTimestampFormatted];
    
    NSString *infoContent = [NSString stringWithFormat:@"Original Path: %@\nDecryption Time: %@\nStatus: %@\nOutput Path: %@",
                           sourcePath, timestamp, result ? @"Success" : @"Failed", outputPath];
    [infoContent writeToFile:infoPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - File Processing

+ (BOOL)processAndSaveFileAtPath:(NSString *)filePath toPath:(NSString *)outputPath logCallback:(void(^)(NSString *log))logCallback {
    // Map the file into memory
    void *fileMap;
    size_t fileSize;
    int fd;
    
    if (![self mapFileIntoMemory:filePath fileMap:&fileMap fileSize:&fileSize fileDescriptor:&fd logCallback:logCallback]) {
        return NO;
    }
    
    // Process Mach-O header
    NSLog(@"H3ck - Processing Mach-O header");
    struct mach_header_64 *header = (struct mach_header_64 *)fileMap;
    if (![self validateMachOHeader:header logCallback:logCallback]) {
        munmap(fileMap, fileSize);
        close(fd);
        return NO;
    }
    
    // Check encryption status and decrypt if needed
    BOOL isEncrypted = NO;
    struct encryption_info_command_64 *encCmd = NULL;
    // Fixed: Removed unused variable by not storing the return value
    [self checkEncryptionStatus:header isEncrypted:&isEncrypted encryptionCommand:&encCmd logCallback:logCallback];
    
    BOOL result = NO;
    
    if (isEncrypted && encCmd != NULL) {
        // Decrypt the binary in memory
        result = [self decryptAndSaveBinary:encCmd fileMap:fileMap fileSize:fileSize outputPath:outputPath logCallback:logCallback];
    } else {
        // Not encrypted or already decrypted, just copy the file
        NSLog(@"H3ck - Binary is not encrypted or already decrypted, copying to output");
        result = [self writeDataToFile:fileMap size:fileSize path:outputPath logCallback:logCallback];
    }
    
    // Cleanup
    munmap(fileMap, fileSize);
    close(fd);
    
    return result;
}

+ (BOOL)mapFileIntoMemory:(NSString *)filePath 
                  fileMap:(void **)fileMap 
                 fileSize:(size_t *)fileSize 
            fileDescriptor:(int *)fd 
               logCallback:(void(^)(NSString *log))logCallback {
    // Open file for read-only access
    NSLog(@"H3ck - Opening file for processing");
    *fd = open([filePath UTF8String], O_RDONLY);
    if (*fd < 0) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to open file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    struct stat fileStat;
    if (fstat(*fd, &fileStat) < 0) {
        close(*fd);
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to get file stats: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    *fileSize = fileStat.st_size;
    
    NSLog(@"H3ck - Mapping file into memory with MAP_PRIVATE");
    *fileMap = mmap(NULL, *fileSize, PROT_READ | PROT_WRITE, MAP_PRIVATE, *fd, 0);
    if (*fileMap == MAP_FAILED) {
        close(*fd);
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to map file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    return YES;
}

+ (BOOL)validateMachOHeader:(struct mach_header_64 *)header logCallback:(void(^)(NSString *log))logCallback {
    if (header->magic != MH_MAGIC_64 || header->cputype != CPU_TYPE_ARM64) {
        NSString *errorMsg = @"Not a valid ARM64 Mach-O file";
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    return YES;
}

#pragma mark - Encryption Analysis

+ (BOOL)checkEncryptionStatus:(struct mach_header_64 *)header 
                  isEncrypted:(BOOL *)isEncrypted 
            encryptionCommand:(struct encryption_info_command_64 **)encCmd
                  logCallback:(void(^)(NSString *log))logCallback {
    // Find LC_ENCRYPTION_INFO_64 command
    NSLog(@"H3ck - Searching for encryption info");
    struct load_command *cmd = (struct load_command *)((uintptr_t)header + sizeof(struct mach_header_64));
    BOOL foundEncryptionInfo = NO;
    
    *isEncrypted = NO;
    *encCmd = NULL;
    
    NSLog(@"H3ck - Number of load commands to process: %d", header->ncmds);
    
    for (uint32_t i = 0; i < header->ncmds; i++) {
        uint32_t cmdType = cmd->cmd & ~LC_REQ_DYLD;  // Remove any flags
        NSLog(@"H3ck - Processing load command %d, type: %u (0x%x)", i, cmdType, cmdType);
        
        if (cmdType == LC_ENCRYPTION_INFO_64) {
            foundEncryptionInfo = YES;
            NSLog(@"H3ck - Found LC_ENCRYPTION_INFO_64 command");
            *encCmd = (struct encryption_info_command_64 *)cmd;
            
            NSLog(@"H3ck - Encryption command details:");
            NSLog(@"H3ck -     cryptoff: %u", (*encCmd)->cryptoff);
            NSLog(@"H3ck -     cryptsize: %u", (*encCmd)->cryptsize);
            NSLog(@"H3ck -     cryptid: %u", (*encCmd)->cryptid);
            
            if ((*encCmd)->cryptid == 0) {
                NSString *msg = @"✅ Binary is already decrypted (cryptid=0)";
                NSLog(@"H3ck - %@", msg);
                if (logCallback) logCallback(msg);
                *isEncrypted = NO;
            } else if ((*encCmd)->cryptid == 1) {
                NSLog(@"H3ck - Binary is encrypted (cryptid=1)");
                *isEncrypted = YES;
            }
            break;
        }
        cmd = (struct load_command *)((char *)cmd + cmd->cmdsize);
    }
    
    if (!foundEncryptionInfo) {
        NSString *msg = @"No encryption info found in binary - either not encrypted or invalid format";
        NSLog(@"H3ck - %@", msg);
        if (logCallback) logCallback(msg);
    }
    
    return foundEncryptionInfo;
}

#pragma mark - Decryption Logic

+ (BOOL)decryptAndSaveBinary:(struct encryption_info_command_64 *)encCmd 
                     fileMap:(void *)fileMap 
                    fileSize:(size_t)fileSize 
                  outputPath:(NSString *)outputPath
                 logCallback:(void(^)(NSString *log))logCallback {
    
    NSLog(@"H3ck - Found encrypted segment, attempting decryption in memory");
    if ([self decryptSegmentInMemory:encCmd fileMap:fileMap fileSize:fileSize logCallback:logCallback]) {
        // Set cryptid to 0 to mark as decrypted
        encCmd->cryptid = 0;
        NSString *msg = @"✅ Successfully decrypted binary in memory";
        NSLog(@"H3ck - %@", msg);
        if (logCallback) logCallback(msg);
        
        // Write decrypted binary to new file
        return [self writeDataToFile:fileMap size:fileSize path:outputPath logCallback:logCallback];
    } else {
        NSString *msg = @"❌ Failed to decrypt binary";
        NSLog(@"H3ck - %@", msg);
        if (logCallback) logCallback(msg);
        return NO;
    }
}

+ (BOOL)decryptSegmentInMemory:(struct encryption_info_command_64 *)info 
                       fileMap:(void *)fileMap 
                      fileSize:(size_t)fileSize
                   logCallback:(void(^)(NSString *log))logCallback {
    
    struct mach_header_64 *header = (struct mach_header_64 *)fileMap;
    uint32_t cputype = header->cputype;
    uint32_t cpusubtype = header->cpusubtype;
    
    uint32_t cryptsize = info->cryptsize;
    uint32_t cryptoff = info->cryptoff;
    uint32_t cryptid = info->cryptid;
    
    NSLog(@"H3ck - In-memory decryption info: size=%u, offset=%u, cryptid=%u", cryptsize, cryptoff, cryptid);
    NSLog(@"H3ck - CPU type: %u, CPU subtype: %u", cputype, cpusubtype);
    
    // Calculate alignment parameters
    long pageSize = sysconf(_SC_PAGESIZE);
    uint32_t alignedOffset = (cryptoff / pageSize) * pageSize;
    uint32_t offsetDiff = cryptoff - alignedOffset;
    // uint32_t alignedSize = cryptsize + offsetDiff;  // wrong implementation
    uint32_t alignedSize = ((cryptsize + pageSize - 1) / pageSize) * pageSize; // Ensures cryptsize is aligned to the next full page size.
    
    NSLog(@"H3ck - Page size: %ld", pageSize);
    NSLog(@"H3ck - Aligned offset: %u (original: %u), diff: %u", alignedOffset, cryptoff, offsetDiff);
    NSLog(@"H3ck - Aligned size: %u (original: %u)", alignedSize, cryptsize);
    
    // Prepare temporary file for decryption
    int tempFd;
    char tempPath[64];
    if (![self prepareTempFileWithPath:tempPath fileDescriptor:&tempFd size:alignedSize logCallback:logCallback]) {
        return NO;
    }
    
    // Copy segment to temp file
    void *sourcePtr = (void *)((uintptr_t)fileMap + alignedOffset);
    if (write(tempFd, sourcePtr, alignedSize) != alignedSize) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to write to temp file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        close(tempFd);
        unlink(tempPath);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    // Map the temp file for decryption
    // void *encryptedSegment = mmap(NULL, alignedSize, PROT_READ | PROT_WRITE , MAP_SHARED, tempFd, 0); //old implementation
// new implementaion - using MAP_PRIVATE & PROT_EXEC
    void *encryptedSegment = mmap(NULL, alignedSize, PROT_READ | PROT_WRITE, MAP_PRIVATE, tempFd, 0);
    if (encryptedSegment == MAP_FAILED) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to map temp file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        close(tempFd);
        unlink(tempPath);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    NSLog(@"H3ck - Mapped encrypted segment from temp file at address: %p", encryptedSegment);
    
    // Decrypt the segment
    BOOL decryptResult = [self performDecryption:encryptedSegment 
                                      offsetDiff:offsetDiff 
                                       cryptsize:cryptsize 
                                         cryptid:cryptid 
                                         cputype:cputype 
                                      cpusubtype:cpusubtype
                                     logCallback:logCallback];
    
    if (decryptResult) {
        // Copy decrypted content back to original file map
        void *decryptPtr = (void *)((uintptr_t)encryptedSegment + offsetDiff);
        void *destPtr = (void *)((uintptr_t)fileMap + cryptoff);
        memcpy(destPtr, decryptPtr, cryptsize);
        NSLog(@"H3ck - Copied decrypted data back to memory map");
    }
    
    // Cleanup
    munmap(encryptedSegment, alignedSize);
    close(tempFd);
    unlink(tempPath);
    
    return decryptResult;
}

+ (BOOL)prepareTempFileWithPath:(char *)tempPath 
                 fileDescriptor:(int *)tempFd 
                          size:(uint32_t)size
                   logCallback:(void(^)(NSString *log))logCallback {
    
    strcpy(tempPath, "/tmp/decrypt_segment_XXXXXX");
    *tempFd = mkstemp(tempPath);
    if (*tempFd < 0) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to create temp file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    // Truncate the file to the required size
    if (ftruncate(*tempFd, size) != 0) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to resize temp file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        close(*tempFd);
        unlink(tempPath);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    return YES;
}

+ (BOOL)performDecryption:(void *)encryptedSegment 
               offsetDiff:(uint32_t)offsetDiff 
                cryptsize:(uint32_t)cryptsize 
                  cryptid:(uint32_t)cryptid 
                  cputype:(uint32_t)cputype 
               cpusubtype:(uint32_t)cpusubtype
              logCallback:(void(^)(NSString *log))logCallback {
    
    // Use mremap_encrypted to decrypt the segment
    // void *decryptPtr = (void *)((uintptr_t)encryptedSegment + offsetDiff); // old implementation

    NSLog(@"H3ck - Final decryption address: %p", encryptedSegment);
    NSLog(@"H3ck - Final decryption size: %u", cryptsize);


    // NSLog(@"H3ck - OLd Calling mremap_encrypted with args (addr=%p, len=%u, cryptid=%u, cputype=%u, cpusubtype=%u)", decryptPtr, cryptsize, cryptid, cputype, cpusubtype);

    NSLog(@"H3ck - NEW Calling mremap_encrypted with args (addr=%p, len=%u, cryptid=%u, cputype=%u, cpusubtype=%u)", encryptedSegment, cryptsize, cryptid, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL);
    
    
    // int error = mremap_encrypted(decryptPtr, cryptsize, cryptid, cputype, cpusubtype); // old implementation
    // int error = mremap_encrypted(encryptedSegment, cryptsize, cryptid, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL); // using direct encryptedSegment
    // if (error != 0) {
    //     NSString *errorMsg = [NSString stringWithFormat:@"Decryption failed: %s", strerror(errno)];
    //     NSLog(@"H3ck - %@", errorMsg);
    //     if (logCallback) logCallback(errorMsg);
    //     return NO;
    // }

    int error = mremap_encrypted(encryptedSegment, cryptsize, cryptid, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL);
    if (error != 0) {
        perror("H3ck - mremap_encrypted failed");
        int errCode = errno;
        NSString *detailedError;

        switch (errCode) {
            case EPERM: 
                detailedError = @"Operation not permitted (Check entitlements or SIP).";
                break;
            case EINVAL: 
                detailedError = @"Invalid arguments (Check segment size, offset, or cryptid).";
                break;
            case EFAULT: 
                detailedError = @"Invalid memory address (Memory mapping issue).";
                break;
            case ENOMEM: 
                detailedError = @"Not enough memory (Try allocating more space).";
                break;
            default: 
                detailedError = @"Unknown error.";
                break;
    }

    NSString *errorMsg = [NSString stringWithFormat:@"Decryption failed: %s (errno: %d) - %@", strerror(errCode), errCode, detailedError];
    NSLog(@"H3ck - %@", errorMsg);
    if (logCallback) logCallback(errorMsg);
    return NO;
}

    
    NSLog(@"H3ck - mremap_encrypted succeeded");
    return YES;
}

#pragma mark - File Operations

+ (BOOL)writeDataToFile:(void *)data size:(size_t)size path:(NSString *)path logCallback:(void(^)(NSString *log))logCallback {
    NSLog(@"H3ck - Writing decrypted binary to: %@", path);
    
    int outFd = open([path UTF8String], O_CREAT | O_WRONLY | O_TRUNC, 0755);
    if (outFd < 0) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to create output file: %s", strerror(errno)];
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        return NO;
    }
    
    // Write the entire binary to the new file
    ssize_t written = write(outFd, data, size);
    if (written != size) {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to write all data: %zd of %zu bytes written", written, size];
        NSLog(@"H3ck - %@", errorMsg);
        if (logCallback) logCallback(errorMsg);
        close(outFd);
        return NO;
    }
    
    NSLog(@"H3ck - Successfully wrote %zd bytes to file", written);
    close(outFd);
    return YES;
}

@end
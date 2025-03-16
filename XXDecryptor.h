#import <Foundation/Foundation.h>

@interface XXDecryptor : NSObject

/**
 * Decrypts an iOS binary file and saves it to a new location.
 * 
 * @param sourcePath The path to the encrypted binary file.
 * @param targetPath The path where the decrypted binary should be saved. If nil, a default path will be used.
 * @param logCallback Optional callback for receiving progress and error messages.
 * @return YES if decryption was successful, NO otherwise.
 */
+ (BOOL)decryptBinary:(NSString *)sourcePath toPath:(NSString *)targetPath withLog:(void(^)(NSString *log))logCallback;

/**
 * Checks if a binary file is encrypted.
 *
 * @param binaryPath The path to the binary file to check.
 * @param logCallback Optional callback for receiving progress and error messages.
 * @return YES if the binary is encrypted, NO if it's not encrypted or an error occurred.
 */
+ (BOOL)isBinaryEncrypted:(NSString *)binaryPath withLog:(void(^)(NSString *log))logCallback;

@end
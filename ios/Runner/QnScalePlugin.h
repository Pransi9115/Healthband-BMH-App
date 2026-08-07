//
//  QnScalePlugin.h
//  Copy to ios/Runner/QnScalePlugin.h
//
//  Written in Objective-C on purpose. QNSDK is an Objective-C library,
//  and Swift renames imported Objective-C methods in ways that are not
//  obvious from the documentation — sharedBleApi became shared,
//  setter methods became properties, ints became Int32. Every one of
//  those cost a build to discover. In Objective-C the signatures in
//  Qingniu's own documentation are the signatures you write.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface QnScalePlugin : NSObject

+ (void)registerWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

NS_ASSUME_NONNULL_END

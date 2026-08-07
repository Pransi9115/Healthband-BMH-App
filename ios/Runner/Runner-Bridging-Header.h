//
//  ios/Runner/Runner-Bridging-Header.h
//
//  Keep whatever is already in yours and add the QnScalePlugin line.
//  Removing the GeneratedPluginRegistrant import stops every Flutter
//  plugin registering.
//

#import "GeneratedPluginRegistrant.h"

// The scale bridge is Objective-C, so AppDelegate.swift reaches it
// through here. QNSDK itself is imported inside QnScalePlugin.m and
// does not need to appear in this file.

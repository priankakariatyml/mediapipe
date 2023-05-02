// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import "mediapipe/tasks/ios/core/sources/MPPTaskOptions.h"
#import "mediapipe/tasks/ios/vision/core/sources/MPPRunningMode.h"
#import "mediapipe/tasks/ios/vision/object_detector/sources/MPPObjectDetectionResult.h"

NS_ASSUME_NONNULL_BEGIN

@class MPPObjectDetector;

/**
 * This protocol defines an interface for the delegates of `MPPImageClassifier` object to receive
 * results of performing asynchronous object detection on images
 * (i.e, when `runningMode` = `MPPRunningModeLiveStream`).
 *
 * The delegate of `MPPImageClassifier` must adopt `MPPImageClassifierDelegate` protocol.
 * The methods in this protocol are optional.
 * TODO: Add parameter `MPPImage` in the callback.
 */
@protocol MPPObjectDetectorDelegate <NSObject>
@required
- (void)objectDetector:(MPPObjectDetector *)objectDetector
    didFinishDetectionWithResult:(nullable MPPObjectDetectionResult *)result
         timestampInMilliseconds:(NSInteger)timestampInMilliseconds
                           error:(nullable NSError *)error
    NS_SWIFT_NAME(objectDetector(_:didFinishDetection:timestampInMilliseconds:error:));
@end

/** Options for setting up a `MPPObjectDetector`. */
NS_SWIFT_NAME(ObjectDetectorOptions)
@interface MPPObjectDetectorOptions : MPPTaskOptions <NSCopying>

/**
 * Running mode of the object detector task. Defaults to `MPPRunningModeImage`.
 * `MPPImageClassifier` can be created with one of the following running modes:
 *  1. `MPPRunningModeImage`: The mode for performing object detection on single image inputs.
 *  2. `MPPRunningModeVideo`: The mode for performing object detection on the decoded frames of a
 *      video.
 *  3. `MPPRunningModeLiveStream`: The mode for performing object detection on a live stream of
 *      input data, such as from the camera.
 */
@property(nonatomic) MPPRunningMode runningMode;

/**
 * An object that confirms to `MPPObjectDetectorDelegate` protocol. This object must implement
 * `objectDetector:didFinishDetectionWithResult:timestampInMilliseconds:error:`
 * to receive the results of performing asynchronous object detection on images (i.e, when
 * `runningMode` = `MPPRunningModeLiveStream`).
 */
@property(nonatomic, weak) id<MPPObjectDetectorDelegate> objectDetectorDelegate;

/**
 * The locale to use for display names specified through the TFLite Model Metadata, if any. Defaults
 * to English.
 */
@property(nonatomic, copy) NSString *displayNamesLocale;

/**
 * The maximum number of top-scored classification results to return. If < 0, all available results
 * will be returned. If 0, an invalid argument error is returned.
 */
@property(nonatomic) NSInteger maxResults;

/**
 * Score threshold to override the one provided in the model metadata (if any). Results below this
 * value are rejected.
 */
@property(nonatomic) float scoreThreshold;

/**
 * The allowlist of category names. If non-empty, detection results whose category name is not in
 * this set will be filtered out. Duplicate or unknown category names are ignored. Mutually
 * exclusive with categoryDenylist.
 */
@property(nonatomic, copy) NSArray<NSString *> *categoryAllowlist;

/**
 * The denylist of category names. If non-empty, detection results whose category name is in this
 * set will be filtered out. Duplicate or unknown category names are ignored. Mutually exclusive
 * with categoryAllowlist.
 */
@property(nonatomic, copy) NSArray<NSString *> *categoryDenylist;

@end

NS_ASSUME_NONNULL_END

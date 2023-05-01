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

#import "mediapipe/tasks/ios/vision/object_detector/sources/MPPObjectDetector.h"

#import "mediapipe/tasks/ios/common/utils/sources/MPPCommonUtils.h"
#import "mediapipe/tasks/ios/common/utils/sources/NSString+Helpers.h"
#import "mediapipe/tasks/ios/core/sources/MPPTaskInfo.h"
#import "mediapipe/tasks/ios/vision/core/sources/MPPVisionPacketCreator.h"
#import "mediapipe/tasks/ios/vision/core/sources/MPPVisionTaskRunner.h"
#import "mediapipe/tasks/ios/vision/object_detector/utils/sources/MPPObjectDetectionResult+Helpers.h"
#import "mediapipe/tasks/ios/vision/object_detector/utils/sources/MPPObjectDetectorOptions+Helpers.h"

namespace {
using ::mediapipe::NormalizedRect;
using ::mediapipe::Packet;
using ::mediapipe::Timestamp;
using ::mediapipe::tasks::core::PacketMap;
using ::mediapipe::tasks::core::PacketsCallback;
}  // namespace

static NSString *const kDetectionsStreamName = @"detections_out";
static NSString *const kDetectionsTag = @"DETECTIONS";
static NSString *const kImageInStreamName = @"image_in";
static NSString *const kImageOutStreamName = @"image_out";
static NSString *const kImageTag = @"IMAGE";
static NSString *const kNormRectStreamName = @"norm_rect_in";
static NSString *const kNormRectTag = @"NORM_RECT";

static NSString *const kTaskGraphName = @"mediapipe.tasks.vision.ObjectDetectorGraph";

#define InputPacketMap(imagePacket, normalizedRectPacket) \
  {                                                       \
    {kImageInStreamName.cppString, imagePacket}, {        \
      kNormRectStreamName.cppString, normalizedRectPacket \
    }                                                     \
  }

@interface MPPObjectDetector () {
  /** iOS Vision Task Runner */
  MPPVisionTaskRunner *_visionTaskRunner;
}
@end

@implementation MPPObjectDetector

- (instancetype)initWithOptions:(MPPObjectDetectorOptions *)options error:(NSError **)error {
  self = [super init];
  if (self) {
    MPPTaskInfo *taskInfo = [[MPPTaskInfo alloc]
        initWithTaskGraphName:kTaskGraphName
                 inputStreams:@[
                   [NSString stringWithFormat:@"%@:%@", kImageTag, kImageInStreamName],
                   [NSString stringWithFormat:@"%@:%@", kNormRectTag, kNormRectStreamName]
                 ]
                outputStreams:@[
                  [NSString stringWithFormat:@"%@:%@", kDetectionsTag, kDetectionsStreamName],
                  [NSString stringWithFormat:@"%@:%@", kImageTag, kImageOutStreamName]
                ]
                  taskOptions:options
           enableFlowLimiting:options.runningMode == MPPRunningModeLiveStream
                        error:error];

    if (!taskInfo) {
      return nil;
    }

    PacketsCallback packetsCallback = nullptr;

    if (options.objectDetectorDelegate) {
      _objectDetectorDelegate = options.objectDetectorDelegate;
      packetsCallback = [=](absl::StatusOr<PacketMap> status_or_packets) {
        NSError *callbackError = nil;
        if (![MPPCommonUtils checkCppError:status_or_packets.status() toError:&callbackError]) {
          if ([_objectDetectorDelegate
                  respondsToSelector:@selector(objectDetector:
                                         didFinishObjectDetectionWithResult:timestampInMilliseconds:error:)]) {
            [_objectDetectorDelegate objectDetector:self
                didFinishObjectDetectionWithResult:nil
                               timestampInMilliseconds:Timestamp::Unset().Value()
                                                 error:&callbackError];
          }
          return;
        }

         PacketMap &outputPacketMap = status_or_packets.value();
        if (outputPacketMap[kImageOutStreamName.cppString].IsEmpty()) {
          return;
        }

        MPPObjectDetectionResult *result = [MPPObjectDetectionResult
            objectDetectionResultWithDetectionsPacket:statusOrPackets.value()[kDetectionsStreamName
                                                                                  .cppString]];

        if ([_objectDetectorDelegate
                respondsToSelector:@selector(objectDetector:
                                         didFinishObjectDetectionWithResult:timestampInMilliseconds:error:)]) {
                           
            [_objectDetectorDelegate objectDetector:self
              didFinishObjectDetectionWithResult:result
                             timestampInMilliseconds:outputPacketMap[kImageOutStreamName.cppString]
                                                         .Timestamp()
                                                         .Value() /
                                                     kMicroSecondsPerMilliSecond
                                               error:&callbackError];
        }
      };
    }

    _visionTaskRunner =
        [[MPPVisionTaskRunner alloc] initWithCalculatorGraphConfig:[taskInfo generateGraphConfig]
                                                       runningMode:options.runningMode
                                                   packetsCallback:std::move(packetsCallback)
                                                             error:error];

    if (!_visionTaskRunner) {
      return nil;
    }
  }
  return self;
}

- (instancetype)initWithModelPath:(NSString *)modelPath error:(NSError **)error {
  MPPObjectDetectorOptions *options = [[MPPObjectDetectorOptions alloc] init];

  options.baseOptions.modelAssetPath = modelPath;

  return [self initWithOptions:options error:error];
}

- (nullable MPPObjectDetectionResult *)detectInImage:(MPPImage *)image
                                    regionOfInterest:(CGRect)roi
                                               error:(NSError **)error {
  std::optional<NormalizedRect> rect =
      [_visionTaskRunner normalizedRectFromRegionOfInterest:roi
                                           imageOrientation:image.orientation
                                                 ROIAllowed:YES
                                                      error:error];
  if (!rect.has_value()) {
    return nil;
  }

  Packet imagePacket = [MPPVisionPacketCreator createPacketWithMPPImage:image error:error];
  if (imagePacket.IsEmpty()) {
    return nil;
  }

  Packet normalizedRectPacket =
      [MPPVisionPacketCreator createPacketWithNormalizedRect:rect.value()];

  PacketMap inputPacketMap = InputPacketMap(imagePacket, normalizedRectPacket);

  std::optional<PacketMap> outputPacketMap = [_visionTaskRunner processImagePacketMap:inputPacketMap
                                                                                error:error];
  if (!outputPacketMap.has_value()) {
    return nil;
  }

  return [MPPObjectDetectionResult
      objectDetectionResultWithDetectionsPacket:outputPacketMap
                                                    .value()[kDetectionsStreamName.cppString]];
}

- (std::optional<PacketMap>)inputPacketMapWithMPPImage:(MPPImage *)image
                               timestampInMilliseconds:(NSInteger)timestampInMilliseconds
                                      regionOfInterest:(CGRect)roi
                                                 error:(NSError **)error {
  std::optional<NormalizedRect> rect =
      [_visionTaskRunner normalizedRectFromRegionOfInterest:roi
                                           imageOrientation:image.orientation
                                                 ROIAllowed:YES
                                                      error:error];
  if (!rect.has_value()) {
    return std::nullopt;
  }

  Packet imagePacket = [MPPVisionPacketCreator createPacketWithMPPImage:image
                                                timestampInMilliseconds:timestampInMilliseconds
                                                                  error:error];
  if (imagePacket.IsEmpty()) {
    return std::nullopt;
  }

  Packet normalizedRectPacket =
      [MPPVisionPacketCreator createPacketWithNormalizedRect:rect.value()
                                     timestampInMilliseconds:timestampInMilliseconds];

  PacketMap inputPacketMap = InputPacketMap(imagePacket, normalizedRectPacket);
  return inputPacketMap;
}

- (nullable MPPObjectDetectionResult *)detectInImage:(MPPImage *)image error:(NSError **)error {
  return [self detectInImage:image regionOfInterest:CGRectZero error:error];
}

- (nullable MPPObjectDetectionResult *)detectInVideoFrame:(MPPImage *)image
                                  timestampInMilliseconds:(NSInteger)timestampInMilliseconds
                                         regionOfInterest:(CGRect)roi
                                                    error:(NSError **)error {
  std::optional<PacketMap> inputPacketMap = [self inputPacketMapWithMPPImage:image
                                                     timestampInMilliseconds:timestampInMilliseconds
                                                            regionOfInterest:roi
                                                                       error:error];
  if (!inputPacketMap.has_value()) {
    return nil;
  }

  std::optional<PacketMap> outputPacketMap =
      [_visionTaskRunner processVideoFramePacketMap:inputPacketMap.value() error:error];

  if (!outputPacketMap.has_value()) {
    return nil;
  }

  return [MPPObjectDetectionResult
      objectDetectionResultWithDetectionsPacket:outputPacketMap
                                                    .value()[kDetectionsStreamName.cppString]];
}

- (nullable MPPObjectDetectionResult *)detectInVideoFrame:(MPPImage *)image
                                  timestampInMilliseconds:(NSInteger)timestampInMilliseconds
                                                    error:(NSError **)error {
  return [self detectInVideoFrame:image
          timestampInMilliseconds:timestampInMilliseconds
                 regionOfInterest:CGRectZero
                            error:error];
}

- (BOOL)detectAsyncInImage:(MPPImage *)image
    timestampInMilliseconds:(NSInteger)timestampInMilliseconds
           regionOfInterest:(CGRect)roi
                      error:(NSError **)error {
  std::optional<PacketMap> inputPacketMap = [self inputPacketMapWithMPPImage:image
                                                     timestampInMilliseconds:timestampInMilliseconds
                                                            regionOfInterest:roi
                                                                       error:error];
  if (!inputPacketMap.has_value()) {
    return NO;
  }

  return [_visionTaskRunner processLiveStreamPacketMap:inputPacketMap.value() error:error];
}

- (BOOL)detectAsyncInImage:(MPPImage *)image
    timestampInMilliseconds:(NSInteger)timestampInMilliseconds
                      error:(NSError **)error {
  return [self detectAsyncInImage:image
          timestampInMilliseconds:timestampInMilliseconds
                 regionOfInterest:CGRectZero
                            error:error];
}

@end

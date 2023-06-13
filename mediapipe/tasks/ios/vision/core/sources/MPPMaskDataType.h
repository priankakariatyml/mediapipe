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

NS_ASSUME_NONNULL_BEGIN

/** The underlying type of the image. */
typedef NS_ENUM(NSUInteger, MPPMaskDataType) {

  // Generic error codes.

  /** The mode for running a mediapipe vision task on single image inputs. */
  MPPMaskDataTypeUInt8,

  /** The mode for running a mediapipe vision task on the decoded frames of a video. */
  MPPMaskDataTypeFloat32,

} NS_SWIFT_NAME(MaskDataType);

NS_ASSUME_NONNULL_END
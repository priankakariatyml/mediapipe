// Copyright 2022 The MediaPipe Authors.
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

#import "mediapipe/tasks/ios/core/sources/MPPTaskRunner.h"
#import "mediapipe/tasks/ios/common/utils/sources/MPPCommonUtils.h"

#include "mediapipe/tasks/cc/core/mediapipe_builtin_op_resolver.h"

namespace {
using ::mediapipe::CalculatorGraphConfig;
using ::mediapipe::tasks::core::MediaPipeBuiltinOpResolver;
using ::mediapipe::tasks::core::PacketMap;
using ::mediapipe::tasks::core::PacketsCallback;
using TaskRunnerCpp = ::mediapipe::tasks::core::TaskRunner;
}  // namespace

@interface MPPTaskRunner () {
  // Cpp Task Runner
  std::unique_ptr<TaskRunnerCpp> _cppTaskRunner;
  BOOL initializedWithPacketsCallback;
}
@end

@implementation MPPTaskRunner

- (instancetype)initWithCalculatorGraphConfig:(CalculatorGraphConfig)graphConfig
                              packetsCallback:(PacketsCallback)packetsCallback
                                        error:(NSError **)error {
  self = [super init];
  if (self) {    
    auto taskRunnerResult = TaskRunnerCpp::Create(std::move(graphConfig),
                                                  absl::make_unique<MediaPipeBuiltinOpResolver>(),
                                                  std::move(packetsCallback));

    if (![MPPCommonUtils checkCppError:taskRunnerResult.status() toError:error]) {
      return nil;
    }
    _cppTaskRunner = std::move(taskRunnerResult.value());
    _initializedWithPacketsCallback = packetsCallback ? YES : NO;
  }
  return self;
}

- (std::optional<PacketMap>)processPacketMap:(const PacketMap &)packetMap error:(NSError **)error {
  absl::StatusOr<PacketMap> resultPacketMap = _cppTaskRunner->Process(packetMap);
  if (![MPPCommonUtils checkCppError:resultPacketMap.status() toError:error]) {
    return std::nullopt;
  }
  return resultPacketMap.value();
}

- (BOOL)sendPacketMap:(const PacketMap &)packetMap error:(NSError **)error {
  if (!_initializedWithPacketsCallback) {
    [MPPCommonUtils
        createCustomError:error
                 withCode:MPPTasksErrorCodeInvalidArgumentError
              description:[NSString stringWithFormat:@"This method can only be called if the task is running in a stream mode."]];
    return NO;
  }
  
  absl::Status sendStatus = _cppTaskRunner->Send(packetMap);
  
  return [MPPCommonUtils checkCppError:sendStatus toError:error];
}

- (BOOL)closeWithError:(NSError **)error {
  absl::Status closeStatus = _cppTaskRunner->Close();
  return [MPPCommonUtils checkCppError:closeStatus toError:error];
}

@end

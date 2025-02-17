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
#import <XCTest/XCTest.h>

#import "mediapipe/tasks/ios/common/sources/MPPCommon.h"
#import "mediapipe/tasks/ios/test/vision/utils/sources/MPPImage+TestUtils.h"
#import "mediapipe/tasks/ios/test/vision/utils/sources/MPPMask+TestUtils.h"
#import "mediapipe/tasks/ios/vision/interactive_segmenter/sources/MPPInteractiveSegmenter.h"
#import "mediapipe/tasks/ios/vision/interactive_segmenter/sources/MPPInteractiveSegmenterResult.h"

#include <iostream>
#include <vector>

static MPPFileInfo *const kCatsAndDogsImageFileInfo =
    [[MPPFileInfo alloc] initWithName:@"cats_and_dogs" type:@"jpg"];
static MPPFileInfo *const kCatsAndDogsMaskImage1FileInfo =
    [[MPPFileInfo alloc] initWithName:@"cats_and_dogs_mask_dog1" type:@"png"];
static MPPFileInfo *const kCatsAndDogsMaskImage2FileInfo =
    [[MPPFileInfo alloc] initWithName:@"cats_and_dogs_mask_dog2" type:@"png"];

static MPPFileInfo *const kDeepLabModelFileInfo =
    [[MPPFileInfo alloc] initWithName:@"ptm_512_hdt_ptm_woid" type:@"tflite"];

static NSString *const kExpectedErrorDomain = @"com.google.mediapipe.tasks";

constexpr NSInteger kMagnificationFactor = 255;

#define AssertEqualErrors(error, expectedError)              \
  XCTAssertNotNil(error);                                    \
  XCTAssertEqualObjects(error.domain, expectedError.domain); \
  XCTAssertEqual(error.code, expectedError.code);            \
  XCTAssertEqualObjects(error.localizedDescription, expectedError.localizedDescription)

namespace {
double sum(const std::vector<float> &mask) {
  double sum = 0.0;
  for (const float &maskElement : mask) {
    sum += maskElement;
  }
  return sum;
}

std::vector<float> multiply(const float *mask1, const float *mask2, size_t size) {
  std::vector<float> multipliedMask;
  multipliedMask.reserve(size);

  for (int i = 0; i < size; i++) {
    multipliedMask.push_back(mask1[i] * mask2[i]);
  }

  return multipliedMask;
}

double softIOU(const float *mask1, const float *mask2, size_t size) {
  std::vector<float> interSectionVector = multiply(mask1, mask2, size);
  double interSectionSum = sum(interSectionVector);

  std::vector<float> m1m1Vector = multiply(mask1, mask1, size);
  double m1m1 = sum(m1m1Vector);

  std::vector<float> m2m2Vector = multiply(mask2, mask2, size);
  double m2m2 = sum(m2m2Vector);

  double unionSum = m1m1 + m2m2 - interSectionSum;

  return unionSum > 0.0 ? interSectionSum / unionSum : 0.0;
}
}  // namespace

@interface MPPInteractiveSegmenterTests : XCTestCase
@end

@implementation MPPInteractiveSegmenterTests

#pragma mark General Tests

- (void)setUp {
  // When expected and actual mask sizes are not equal, iterating through mask data results in a
  // segmentation fault. Setting this property to `NO`, prevents each test case from executing the
  // remaining flow after a failure. Since expected and actual mask sizes are compared before
  // iterating through them, this prevents any illegal memory access.
  self.continueAfterFailure = NO;
}

+ (NSString *)filePathWithName:(NSString *)fileName extension:(NSString *)extension {
  NSString *filePath =
      [[NSBundle bundleForClass:[MPPInteractiveSegmenterTests class]] pathForResource:fileName
                                                                               ofType:extension];
  return filePath;
}

#pragma mark Image Mode Tests

- (void)testSegmentWithCategoryMaskSucceeds {
  MPPInteractiveSegmenterOptions *options =
      [self interactiveSegmenterOptionsWithModelFileInfo:kDeepLabModelFileInfo];
  options.shouldOutputConfidenceMasks = NO;
  options.shouldOutputCategoryMask = YES;

  MPPInteractiveSegmenter *interactiveSegmenter =
      [self createInteractiveSegmenterWithOptionsSucceeds:options];

  MPPRegionOfInterest *regionOfInterest = [[MPPRegionOfInterest alloc]
      initWithNormalizedKeyPoint:[[MPPNormalizedKeypoint alloc]
                                     initWithLocation:CGPointMake(0.44, 0.7)
                                                label:nil
                                                score:0.0f]];
  [self assertResultsOfSegmentImageWithFileInfo:kCatsAndDogsImageFileInfo
                                              regionOfInterest:regionOfInterest
                                     usingInteractiveSegmenter:interactiveSegmenter
      approximatelyEqualsExpectedCategoryMaskImageWithFileInfo:kCatsAndDogsMaskImage1FileInfo
                                   withmaskSimilarityThreshold:0.84f
                                     shouldHaveConfidenceMasks:NO];
}

- (void)testSegmentWithConfidenceMaskSucceeds {
  MPPInteractiveSegmenterOptions *options =
      [self interactiveSegmenterOptionsWithModelFileInfo:kDeepLabModelFileInfo];

  MPPInteractiveSegmenter *interactiveSegmenter =
      [self createInteractiveSegmenterWithOptionsSucceeds:options];

  MPPRegionOfInterest *regionOfInterest = [[MPPRegionOfInterest alloc]
      initWithNormalizedKeyPoint:[[MPPNormalizedKeypoint alloc]
                                     initWithLocation:CGPointMake(0.44, 0.7)
                                                label:nil
                                                score:0.0f]];

  [self assertResultsOfSegmentImageWithFileInfo:kCatsAndDogsImageFileInfo
                                                regionOfInterest:regionOfInterest
                                       usingInteractiveSegmenter:interactiveSegmenter
                                         hasConfidenceMasksCount:2
      approximatelyEqualsExpectedConfidenceMaskImageWithFileInfo:kCatsAndDogsMaskImage1FileInfo
                                                         atIndex:1
                                     withmaskSimilarityThreshold:0.84f
                                          shouldHaveCategoryMask:NO];
}

#pragma mark - Image Segmenter Initializers

- (MPPInteractiveSegmenterOptions *)interactiveSegmenterOptionsWithModelFileInfo:
    (MPPFileInfo *)fileInfo {
  MPPInteractiveSegmenterOptions *options = [[MPPInteractiveSegmenterOptions alloc] init];
  options.baseOptions.modelAssetPath = fileInfo.path;
  return options;
}

- (MPPInteractiveSegmenter *)createInteractiveSegmenterWithOptionsSucceeds:
    (MPPInteractiveSegmenterOptions *)options {
  NSError *error;
  MPPInteractiveSegmenter *interactiveSegmenter =
      [[MPPInteractiveSegmenter alloc] initWithOptions:options error:&error];
  XCTAssertNotNil(interactiveSegmenter);
  XCTAssertNil(error);

  return interactiveSegmenter;
}

- (void)assertCreateInteractiveSegmenterWithOptions:(MPPInteractiveSegmenterOptions *)options
                             failsWithExpectedError:(NSError *)expectedError {
  NSError *error = nil;
  MPPInteractiveSegmenter *interactiveSegmenter =
      [[MPPInteractiveSegmenter alloc] initWithOptions:options error:&error];

  XCTAssertNil(interactiveSegmenter);
  AssertEqualErrors(error, expectedError);
}

#pragma mark Assert Segmenter Results
- (void)assertResultsOfSegmentImageWithFileInfo:(MPPFileInfo *)imageFileInfo
                                            regionOfInterest:(MPPRegionOfInterest *)regionOfInterest
                                   usingInteractiveSegmenter:
                                       (MPPInteractiveSegmenter *)interactiveSegmenter
    approximatelyEqualsExpectedCategoryMaskImageWithFileInfo:
        (MPPFileInfo *)expectedCategoryMaskFileInfo
                                 withmaskSimilarityThreshold:(const float)maskSimilarityThreshold
                                   shouldHaveConfidenceMasks:(BOOL)shouldHaveConfidenceMasks {
  MPPInteractiveSegmenterResult *result = [self segmentImageWithFileInfo:imageFileInfo
                                                        regionOfInterest:regionOfInterest
                                               usingInteractiveSegmenter:interactiveSegmenter];

  XCTAssertNotNil(result.categoryMask);

  if (shouldHaveConfidenceMasks) {
    XCTAssertNotNil(result.confidenceMasks);
  } else {
    XCTAssertNil(result.confidenceMasks);
  }

  [self assertCategoryMask:result.categoryMask
      approximatelyEqualsExpectedCategoryMaskImageWithFileInfo:expectedCategoryMaskFileInfo
                                   withmaskSimilarityThreshold:maskSimilarityThreshold];
}

- (void)assertResultsOfSegmentImageWithFileInfo:(MPPFileInfo *)imageFileInfo
                                              regionOfInterest:
                                                  (MPPRegionOfInterest *)regionOfInterest
                                     usingInteractiveSegmenter:
                                         (MPPInteractiveSegmenter *)interactiveSegmenter
                                       hasConfidenceMasksCount:
                                           (NSUInteger)expectedConfidenceMasksCount
    approximatelyEqualsExpectedConfidenceMaskImageWithFileInfo:
        (MPPFileInfo *)expectedConfidenceMaskFileInfo
                                                       atIndex:(NSInteger)index
                                   withmaskSimilarityThreshold:(const float)maskSimilarityThreshold
                                        shouldHaveCategoryMask:(BOOL)shouldHaveCategoryMask {
  MPPInteractiveSegmenterResult *result = [self segmentImageWithFileInfo:imageFileInfo
                                                        regionOfInterest:regionOfInterest
                                               usingInteractiveSegmenter:interactiveSegmenter];

  [self assertInteractiveSegmenterResult:result
                                         hasConfidenceMasksCount:expectedConfidenceMasksCount
      approximatelyEqualsExpectedConfidenceMaskImageWithFileInfo:expectedConfidenceMaskFileInfo
                                                         atIndex:index
                                     withmaskSimilarityThreshold:maskSimilarityThreshold
                                          shouldHaveCategoryMask:shouldHaveCategoryMask];
}

- (void)assertInteractiveSegmenterResult:(MPPInteractiveSegmenterResult *)result
                                       hasConfidenceMasksCount:
                                           (NSUInteger)expectedConfidenceMasksCount
    approximatelyEqualsExpectedConfidenceMaskImageWithFileInfo:
        (MPPFileInfo *)expectedConfidenceMaskFileInfo
                                                       atIndex:(NSInteger)index
                                   withmaskSimilarityThreshold:(const float)maskSimilarityThreshold
                                        shouldHaveCategoryMask:(BOOL)shouldHaveCategoryMask {
  XCTAssertNotNil(result.confidenceMasks);

  XCTAssertEqual(result.confidenceMasks.count, expectedConfidenceMasksCount);

  if (shouldHaveCategoryMask) {
    XCTAssertNotNil(result.categoryMask);
  } else {
    XCTAssertNil(result.categoryMask);
  }

  XCTAssertLessThan(index, result.confidenceMasks.count);

  [self assertConfidenceMask:result.confidenceMasks[index]
      approximatelyEqualsExpectedConfidenceMaskImageWithFileInfo:expectedConfidenceMaskFileInfo
                                     withmaskSimilarityThreshold:maskSimilarityThreshold];
}

- (MPPInteractiveSegmenterResult *)segmentImageWithFileInfo:(MPPFileInfo *)fileInfo
                                           regionOfInterest:(MPPRegionOfInterest *)regionOfInterest
                                  usingInteractiveSegmenter:
                                      (MPPInteractiveSegmenter *)interactiveSegmenter {
  MPPImage *image = [MPPImage imageWithFileInfo:fileInfo];
  XCTAssertNotNil(image);

  NSError *error;

  MPPInteractiveSegmenterResult *result = [interactiveSegmenter segmentImage:image
                                                            regionOfInterest:regionOfInterest
                                                                       error:&error];

  XCTAssertNil(error);
  XCTAssertNotNil(result);

  return result;
}

- (void)assertCategoryMask:(MPPMask *)categoryMask
    approximatelyEqualsExpectedCategoryMaskImageWithFileInfo:
        (MPPFileInfo *)expectedCategoryMaskImageFileInfo
                                 withmaskSimilarityThreshold:(const float)maskSimilarityThreshold {
  MPPMask *expectedCategoryMask =
      [[MPPMask alloc] initWithImageFileInfo:expectedCategoryMaskImageFileInfo];

  XCTAssertEqual(categoryMask.width, expectedCategoryMask.width);
  XCTAssertEqual(categoryMask.height, expectedCategoryMask.height);

  size_t maskSize = categoryMask.width * categoryMask.height;

  const UInt8 *categoryMaskPixelData = categoryMask.uint8Data;
  const UInt8 *expectedCategoryMaskPixelData = expectedCategoryMask.uint8Data;

  NSInteger consistentPixels = 0;

  for (int i = 0; i < maskSize; i++) {
    consistentPixels +=
        categoryMaskPixelData[i] * kMagnificationFactor == expectedCategoryMaskPixelData[i] ? 1 : 0;
  }

  XCTAssertGreaterThan((float)consistentPixels / (float)maskSize, maskSimilarityThreshold);
}

- (void)assertConfidenceMask:(MPPMask *)confidenceMask
    approximatelyEqualsExpectedConfidenceMaskImageWithFileInfo:
        (MPPFileInfo *)expectedConfidenceMaskImageFileInfo
                                   withmaskSimilarityThreshold:
                                       (const float)maskSimilarityThreshold {
  MPPMask *expectedConfidenceMask =
      [[MPPMask alloc] initWithImageFileInfo:expectedConfidenceMaskImageFileInfo];

  XCTAssertEqual(confidenceMask.width, expectedConfidenceMask.width);
  XCTAssertEqual(confidenceMask.height, expectedConfidenceMask.height);

  size_t maskSize = confidenceMask.width * confidenceMask.height;

  XCTAssertGreaterThan(
      softIOU(confidenceMask.float32Data, expectedConfidenceMask.float32Data, maskSize),
      maskSimilarityThreshold);
}

@end

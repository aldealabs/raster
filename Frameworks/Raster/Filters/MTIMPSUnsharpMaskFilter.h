//
//  MTIUSMSharpenFilter.h
//  Raster
//
//  Created by yi chen on 2018/2/7.
//

#if __has_include(<Raster/Raster.h>)
#import <Raster/MTIFilter.h>
#else
#import "MTIFilter.h"
#endif

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface MTIMPSUnsharpMaskFilter : NSObject  <MTIUnaryFilter>

@property (nonatomic) float scale; //(0, 1]. Default is 0.5.
@property (nonatomic) float radius;
@property (nonatomic) float threshold; //[0, 1). Default is 0.

@end

NS_ASSUME_NONNULL_END

//
//  MTIPixellateFilter.h
//  Pods
//
//  Created by Yu Ao on 08/01/2018.
//

#if __has_include(<Raster/Raster.h>)
#import <Raster/MTIUnaryImageRenderingFilter.h>
#else
#import "MTIUnaryImageRenderingFilter.h"
#endif

__attribute__((objc_subclassing_restricted))
@interface MTIPixellateFilter : MTIUnaryImageRenderingFilter

/// Specifies the scale of the operation, i.e. the size for the pixels in the resulting image.
@property (nonatomic) CGSize scale;

@end

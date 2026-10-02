#import <UIKit/UIKit.h>

@protocol CCUIContentModule <NSObject>
@optional
- (UIViewController *)contentViewController;
- (UIViewController *)backgroundViewController;
@end

@interface CCUIToggleModule : NSObject <CCUIContentModule>
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, copy, readonly) UIImage *iconGlyph;
@property (nonatomic, copy, readonly) UIImage *selectedIconGlyph;
@property (nonatomic, copy, readonly) UIColor *selectedColor;
- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;
- (void)refreshState;
- (UIImage *)iconGlyph;
- (UIImage *)selectedIconGlyph;
- (UIColor *)selectedColor;
@end

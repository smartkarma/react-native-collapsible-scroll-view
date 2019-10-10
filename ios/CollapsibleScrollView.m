#import "CollapsibleScrollView.h"

#import <UIKit/UIKit.h>
#import <React/RCTScrollView.h>
#import <React/RCTUIManager.h>
#import <React/RCTUIManagerUtils.h>
#import <React/RCTScrollableProtocol.h>

@implementation CollapsibleScrollView

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

NSDictionary *_tabs;
NSNumber *_headerHeight;
NSNumber *_tabContentWidth = 0;
NSArray *_tabsWidth;

NSUInteger _currentTabIndex = 0;
CGFloat _scrollY = 0;

RCTView *_header;
RCTScrollView *_tabsScrollView;
RCTScrollView *_tabIndicatorView;
RCTScrollView *_tabContentScrollView;
NSMutableDictionary *_scrollViews;
UITapGestureRecognizer *_singleFingerTap;

- (id)init
{
    self = [super init];
    _singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    return self;
}


// hook up the scroll listener after translating the numeric node handle to an actual view
RCT_EXPORT_METHOD(setScrollViewsHandle:(nonnull NSDictionary *) tabs
                  headerViewTag:(nonnull NSNumber *)headerViewTag
                  headerHeight:(nonnull NSNumber *)headerHeight
                  tabsScrollViewTag:(nonnull NSNumber *)tabsScrollViewTag
                  tabIndicatorViewTag:(nonnull NSNumber *)tabIndicatorViewTag
                  tabContentScrollViewTag:(nonnull NSNumber *)tabContentScrollViewTag
                  tabContentWidth:(nonnull NSNumber *)tabContentWidth
                  tabsWidth:(nonnull NSArray *)tabsWidth)
{
    _tabs = tabs;
    _headerHeight = headerHeight;
    _tabContentWidth = tabContentWidth;
    _tabsWidth = tabsWidth;
    
    dispatch_async(RCTGetUIManagerQueue(), ^{
        [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTScrollView *> *viewRegistry)
         {
             _header = viewRegistry[headerViewTag];
             
             _tabsScrollView = viewRegistry[tabsScrollViewTag];
             if (![_tabsScrollView isKindOfClass:[RCTScrollView class]]) {
                 RCTLogError(@"Invalid view returned from registry, expecting RCTScrollView, got: %@", _tabsScrollView);
             } else {
                 [_tabsScrollView addGestureRecognizer:_singleFingerTap];
             }
             
             _tabIndicatorView = viewRegistry[tabIndicatorViewTag];
             
             _tabContentScrollView = viewRegistry[tabContentScrollViewTag];
             if (![_tabContentScrollView isKindOfClass:[RCTScrollView class]]) {
                 RCTLogError(@"Invalid view returned from registry, expecting RCTScrollView, got: %@", _tabContentScrollView);
             } else {
                 _currentTabIndex = [self getCurrentTabIndex:_tabContentScrollView.scrollView.contentOffset.x];
                 // Set initial transform for tabIndicator
                 CGFloat currentTabWidth = [_tabsWidth[_currentTabIndex] floatValue];
                 NSNumber *tabOffset = [self getTabOffset:_currentTabIndex];
                 CGAffineTransform indicatorTransform = CGAffineTransformIdentity;
                 indicatorTransform = CGAffineTransformTranslate(indicatorTransform, [tabOffset floatValue] + currentTabWidth/2, 0);
                 indicatorTransform = CGAffineTransformScale(indicatorTransform, currentTabWidth, 1);
                 _tabIndicatorView.transform = indicatorTransform;
                 [_tabContentScrollView removeScrollListener:self];
                 [_tabContentScrollView addScrollListener:self];
             }
         }];
        
    });
}

// hook up the scroll listener after translating the numeric node handle to an actual view
RCT_EXPORT_METHOD(setScrollViewHandle:(nonnull NSNumber*)scrollViewTag
                  index:(nonnull NSString *) key)
{
    if (_scrollViews == NULL) {
        _scrollViews = [[NSMutableDictionary alloc] init];
    }
    dispatch_async(RCTGetUIManagerQueue(), ^{
        [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTScrollView *> *viewRegistry)
         {
             RCTScrollView *scrollView = viewRegistry[scrollViewTag];
             if (![scrollView isKindOfClass:[RCTScrollView class]]) {
                 RCTLogError(@"Invalid view returned from registry, expecting RCTScrollView, got: %@", scrollView);
             } else {
                 [_scrollViews setObject:scrollView forKey:key];
                 if (scrollView.scrollView.contentOffset.y < _scrollY) {
                     CGPoint offset = CGPointMake(0, _scrollY);
                     [scrollView scrollToOffset:offset animated:false];
                 }
                 [scrollView addScrollListener:self];
             }
         }];
    });
}


RCT_EXPORT_METHOD(clearScrollViewHandle)
{
    // clean up old listener
    [_tabContentScrollView removeScrollListener:self];
    for (id key in _scrollViews) {
        RCTScrollView * scrollView = _scrollViews[key];
        [scrollView removeScrollListener:self];
    }
    [_tabsScrollView removeGestureRecognizer:_singleFingerTap];
    _scrollViews = NULL;
    _scrollY = 0;
};


/**
 ScrollView didScroll event
 
 - transform position of indicator (_tabIndicatorView)
 - transform scroll position of tabs scrollView container
 - transform position of collapsible header (_header)
 - transform position of inactive tabs content scrollView

 @param scrollView
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    @try {
        // Handle horizontal scroll (positionX)
        if (scrollView == _tabContentScrollView.scrollView) {
            CGFloat scrollX = scrollView.contentOffset.x;
            _currentTabIndex = [self getCurrentTabIndex:scrollX];
            
            // Calculate position X for active tab indicator
            CGFloat ratio;
            CGFloat indicatorPosition;
            CGFloat indicatorWidth;
            BOOL isScrolling = scrollX / _currentTabIndex != [_tabContentWidth floatValue];
            NSNumber *currentTabOffset = [self getTabOffset:_currentTabIndex];
            NSNumber *nextTabOffset = [self getTabOffset:_currentTabIndex + 1];
            ratio = scrollX / ([_tabContentWidth floatValue] * (_currentTabIndex + 1));
            CGFloat nextTabWidth = [_tabsWidth[_currentTabIndex + 1] floatValue];
            CGFloat currentTabWidth = [_tabsWidth[_currentTabIndex] floatValue];
            if (isScrolling) {
                CGFloat scrollOffset = MAX(0, (scrollX - ([_tabContentWidth floatValue] * (_currentTabIndex))));
                CGFloat absoluteRatio = scrollOffset / [_tabContentWidth floatValue];
                indicatorWidth = roundf(currentTabWidth - (currentTabWidth * absoluteRatio) + (nextTabWidth * absoluteRatio));
                indicatorPosition = roundf([nextTabOffset floatValue] * ratio + (indicatorWidth / 2)) - 1;
            } else {
                indicatorWidth = [_tabsWidth[_currentTabIndex] floatValue];
                indicatorPosition = [currentTabOffset floatValue] + (indicatorWidth / 2) - 1;
            }
            
            CGFloat currenTabWidth = [_tabsWidth[_currentTabIndex] floatValue];
            CGAffineTransform indicatorTransform = CGAffineTransformIdentity;
            indicatorTransform = CGAffineTransformTranslate(indicatorTransform, indicatorPosition, 0);
            indicatorTransform = CGAffineTransformScale(indicatorTransform, indicatorWidth, 1);
            _tabIndicatorView.transform = indicatorTransform;
            
            
            // Calculate offset of current tab to be in center of bounds
            CGFloat offsetX;
            CGFloat maxOffset = _tabsScrollView.scrollView.contentSize.width - _tabsScrollView.scrollView.bounds.size.width;
            // Calculate offset of current tab to be in center of bounds
            CGFloat scrollToRect = ([currentTabOffset floatValue] + currenTabWidth) - (_tabsScrollView.scrollView.bounds.size.width / 2 + (currenTabWidth / 2));
            offsetX = MAX(0,
                          // Prevent going out of bound
                          MIN(scrollToRect, maxOffset)
                          );
            
            // Scroll to offset
            CGPoint offsetXPoints = CGPointMake(offsetX, 0);
            [_tabsScrollView scrollToOffset:offsetXPoints];
            
            return;
        }
        
        // Handle vertical scrolling (positionY)
        __block BOOL isCurrentTab = NO;
        
        for (id key in _scrollViews) {
            RCTScrollView* currentScrollView = _scrollViews[key];
            NSNumber *currentTabIndex = _tabs[key];
            if (currentScrollView != NULL && _currentTabIndex == [currentTabIndex integerValue] && scrollView == currentScrollView.scrollView) {
                isCurrentTab = YES;
                break;
            }
        }
        
        if (isCurrentTab) {
            _scrollY = scrollView.contentOffset.y;
            if (_scrollY <= 0) {
                _scrollY = 0;
            } else if (_scrollY > [_headerHeight floatValue]) {
                _scrollY = [_headerHeight floatValue];
            }
            
            // Transform position of sticky header container
            _header.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, -(MIN(MAX(_scrollY, 0), [_headerHeight doubleValue])));
            
            // Sync scroll position of inactive tabs content view
            for (id key in _scrollViews) {
                RCTScrollView* currentScrollView = _scrollViews[key];
                NSNumber *currentTabIndex = _tabs[key];
                if (currentScrollView != NULL && _currentTabIndex != [currentTabIndex integerValue]) {
                    CGFloat scrollViewHeight = currentScrollView.scrollView.frame.size.height;
                    CGFloat scrollContentSizeHeight = currentScrollView.scrollView.contentSize.height;
                    if (_scrollY >= 0 && _scrollY + scrollViewHeight <= scrollContentSizeHeight) {
                        CGPoint offset = CGPointMake(0, _scrollY);
                        [currentScrollView scrollToOffset:offset];
                    }
                }
            }
        }
    }
    @catch (NSException *exception) {
        
    }
}

/**
 Get current index based on content scroll offset.
 Calculation is based on the width of each tab content
 ie.: on iPhone SE it will be 320 for each tab content view.
 
 #utility

 @param offset scroll position of the root content view
 @return current tab index
 */
-(NSUInteger)getCurrentTabIndex:(CGFloat)offset
{
    return floorf(offset / [_tabContentWidth floatValue]);
}


/**
 Calculate offset for tab with provided index
 
 #utility

 @param index tab index
 @return offset for tab
 */
- (NSNumber*)getTabOffset:(NSInteger)index {
    NSRange range;
    NSArray *slicedTabs;
    NSNumber *sumOfTabWidth;
    
    range.location = 0;
    range.length = index;
    
    slicedTabs = [_tabsWidth subarrayWithRange:range];
    
    // Sum sliced tabs width
    sumOfTabWidth = [slicedTabs valueForKeyPath:@"@sum.self"];

    return sumOfTabWidth;
}


/**
 Handle tap on scrollView and navigate to corresponding tab

 @param recognizer
 */
- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
    CGPoint location = [recognizer locationInView:[recognizer.view superview]];
    CGPoint offset;
    Boolean withinLocationTap;
    int index = 0;
    NSNumber *sumOfActiveTabsWidth = 0;
    // This location accounts when header scrollView moves
    CGFloat tapLocationAccurate = location.x + _tabsScrollView.scrollView.contentOffset.x;
    do {
        sumOfActiveTabsWidth = [self getTabOffset:index];
        withinLocationTap = [sumOfActiveTabsWidth floatValue] < tapLocationAccurate;
        if (withinLocationTap) index++;
    } while (withinLocationTap);
    CGFloat tabViewOffset = [_tabContentWidth intValue] * (index - 1);
    offset = CGPointMake(tabViewOffset, 0);
    [_tabContentScrollView scrollToOffset:offset];
}

@end
  

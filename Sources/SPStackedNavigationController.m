// Copyright 2014 Spotify
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SPStackedNavigationController.h"
#import "SPStackedPageContainer.h"
#import "SPStackedNavigationScrollView.h"

#import <QuartzCore/QuartzCore.h>

@interface SPStackedNavigationController () <UIScrollViewDelegate, SPStackedNavigationScrollViewDelegate>
{
    SPStackedNavigationScrollView *_scroll;
}
@end

@implementation SPStackedNavigationController

- (id)init
{
    if (!(self = [super init])) return nil;
    return self;
}
- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if (!(self = [self init])) return nil;
    
    [self pushViewController:rootViewController animated:NO];
    [self setActiveViewController:rootViewController position:SPStackedNavigationPagePositionLeft animated:NO completion:nil];
    
    return self;
}

static const float kUnknownFrameSize = 10;
- (void)loadView
{
    CGRect frame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height);
    UIView *root = [[UIView alloc] initWithFrame:frame];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    root.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"backgroundTexture.png"]];
        
    _scroll = [[SPStackedNavigationScrollView alloc] initWithFrame:frame];
    _scroll.delegate = self;
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [root addSubview:_scroll];
    
    self.view = root;
    
    for (UIViewController *viewController in [self childViewControllers])
        [self pushPageContainerWithViewController:viewController];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self setActiveViewController:self.activeViewController position:self.activeViewControllerPagePosition animated:NO completion:nil];
}

#pragma mark view controllers manipulation entry points
- (void)pushPageContainerWithViewController:(UIViewController*)viewController
{
    CGSize size = self.view.frame.size;
    CGRect frame = CGRectMake(self.view.bounds.size.width, 0, 0, size.height);
    frame.size.width = (viewController.stackedNavigationPageSize == kStackedPageHalfSize ?
                        kSPStackedNavigationHalfPageWidth :
                        size.width);
    
    SPStackedPageContainer *pageC = [[SPStackedPageContainer alloc] initWithFrame:frame VC:viewController];
    [_scroll addSubview:pageC];
}

// Only these two methods actually manipulate _viewControllers
- (void)pushViewController:(UIViewController *)viewController
{
    [self pushViewController:viewController onTopOf:self.activeViewController animated:YES];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self pushViewController:viewController animated:animated activate:YES];
}
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated activate:(BOOL)activate
{
    if (!viewController)
        return;
    
    SPStackedNavigationPagePosition activePosition = SPStackedNavigationPagePositionRight;
    if (![self.childViewControllers count])
        activePosition = SPStackedNavigationPagePositionLeft;
    
    if ([viewController parentViewController] == self && activate)
    {
        [self setActiveViewController:viewController position:activePosition animated:animated completion:nil];
        return;
    }
    NSAssert([viewController parentViewController] == nil, @"cannot push view controller with an existing parent");
    
    [self willChangeValueForKey:@"viewControllers"];
    [self addChildViewController:viewController];
    
    if ([self isViewLoaded])
        [self pushPageContainerWithViewController:viewController];
    
    if (activate)
        [self setActiveViewController:viewController position:activePosition animated:animated completion:nil];
    
    [viewController didMoveToParentViewController:self];
    [self didChangeValueForKey:@"viewControllers"];
}
- (void)pushViewController:(UIViewController *)viewController onTopOf:(UIViewController*)parent animated:(BOOL)animated
{
    [self pushViewController:viewController onTopOf:parent animated:animated activate:YES];
}
- (void)pushViewController:(UIViewController *)viewController onTopOf:(UIViewController*)parent animated:(BOOL)animated activate:(BOOL)activate
{
    while (![self.viewControllers containsObject:parent] && parent != nil)
        parent = [parent parentViewController];
    [self popToViewController:parent animated:animated];
    [self pushViewController:viewController animated:animated activate:activate];
}

- (UIViewController *)pop
{
    return [self popViewControllerAnimated:YES];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *viewController = [[self childViewControllers] lastObject];
    if (!viewController)
        return nil;
    
    [self willChangeValueForKey:@"viewControllers"];
    [viewController willMoveToParentViewController:nil];
    
    if ([self isViewLoaded])
    {
        SPStackedPageContainer *pageC = [_scroll containerForViewController:viewController];
        pageC.markedForSuperviewRemoval = YES;
    }
    
    
    [viewController removeFromParentViewController];
    [self didChangeValueForKey:@"viewControllers"];
    
    [self setActiveViewController:[self.childViewControllers lastObject]
                         position:SPStackedNavigationPagePositionRight
                         animated:animated completion:nil];
    
    return viewController;
}

- (void)addTopViewController:(UIViewController*)viewController animated:(BOOL)animated
{
    [self pushViewController:viewController animated:animated activate:NO];
}

//-(void)animateForwardCardNavigationTip
//{
//    if ([self topViewController])
//    {
//        NSArray *cardAndPosition = [NSArray arrayWithObjects:[self topViewController], [NSNumber numberWithFloat:[self topViewController].view.left], nil];
//        [self animateForwardNavigationTipWithCardAndPosition:cardAndPosition checkHistory:NO];
//    }
//}
//
//-(void)animateForwardNavigationTipWithCardAndPosition:(NSArray*)cardAndPosition checkHistory:(BOOL)checkHistory
//{
//    __weak EXViewController *card = [cardAndPosition objectAtIndex:0];
//    float left = [[cardAndPosition objectAtIndex:1] floatValue];
//    BOOL hasMoved = card.view.left != left;
//
//    if (!hasMoved && (!checkHistory || [self shouldAnimateForwardNavigationTipWithCard:card]))
//    {
//        [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
//            card.view.left = left - kEXNavigaionTipAnimationOffset;
//        } completion:^(BOOL finished) {
//            if (finished)
//            {
//                [UIView animateWithDuration:0.2f delay:0.3f options:UIViewAnimationOptionCurveEaseIn animations:^{
//                    card.view.left = left;
//                } completion:^(BOOL finished) {
//                }];
//            }
//        }];
//    }
//}
- (void)removeViewController:(UIViewController*)viewController
{
    if (!viewController)
        return;
    
    [self willChangeValueForKey:@"viewControllers"];
    [viewController willMoveToParentViewController:nil];
    
    if ([self isViewLoaded])
    {
        SPStackedPageContainer *pageC = [_scroll containerForViewController:viewController];
        pageC.markedForSuperviewRemoval = YES;
    }
    
    [viewController removeFromParentViewController];
    [self didChangeValueForKey:@"viewControllers"];
}

- (void)enablePanning
{
    self.panGestureRecognizer.enabled = YES;
}

- (void)disablePanning
{
    self.panGestureRecognizer.enabled = NO;
}

#pragma mark Convenience methods to the above two methods.
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    id commonVC = nil; int startI = NSNotFound;
    for(int i = 0, c = MIN([self.viewControllers count], [viewControllers count]); i < c; i++)
    {
        if ([viewControllers[i] isEqual:(self.viewControllers)[i]])
        {
            startI = i;
            commonVC = viewControllers[i];
        }
        else
            break;
    }
    
    NSArray *toPush = viewControllers;
    if (startI != NSNotFound)
    {
        [self popToViewController:commonVC animated:animated];
        toPush = [viewControllers subarrayWithRange:NSMakeRange(startI+1, [viewControllers count] - startI - 1)];
    }
    for(id vc in toPush)
        [self pushViewController:vc animated:animated];
}
- (void)setViewControllers:(NSArray *)viewControllers
{
    [self setViewControllers:viewControllers animated:NO];
}
- (void)setActiveViewController:(UIViewController*)viewController animated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
    if (self.activeViewController == viewController ||
        [self.viewControllers indexOfObject:viewController] == NSNotFound)
        return;
    NSUInteger currentIndex = [self.viewControllers indexOfObject:self.activeViewController];
    NSUInteger newIndex = [self.viewControllers indexOfObject:viewController];
    [self setActiveViewController:viewController
                         position:(newIndex > currentIndex ?
                                   SPStackedNavigationPagePositionRight :
                                   SPStackedNavigationPagePositionLeft)
                         animated:animated completion:completion];
}
- (void)setActiveViewController:(UIViewController *)viewController position:(SPStackedNavigationPagePosition)position animated:(BOOL)animated completion:(void(^)(BOOL finished))completion
{
    NSArray *viewControllers = [self viewControllers];
    NSUInteger index = [viewControllers indexOfObject:viewController];
    if (index == NSNotFound) return;
    
    [self setActiveViewController:viewController position:position];
    [_scroll setContentOffset:CGPointMake([_scroll scrollOffsetForAligningPage:(_scroll.subviews)[index]
                                                          position:self.activeViewControllerPagePosition],
                                          0)
                     animated:animated completion:completion];
}
- (void)setActiveViewController:(UIViewController *)activeViewController position:(SPStackedNavigationPagePosition)position
{
    if (_activeViewController != activeViewController)
    {
        UIViewController *oldActiveViewController = _activeViewController;
        _activeViewController = activeViewController;
        [oldActiveViewController viewDidBecomeInactiveInStackedNavigation];
        [activeViewController viewDidBecomeActiveInStackedNavigation];
    }
    _activeViewControllerPagePosition = position;
}
- (NSArray *)visibleViewControllers
{
    NSInteger activeIndex = [[self viewControllers] indexOfObject:self.activeViewController];
    if (activeIndex == NSNotFound) {
        return @[];
    }

    if ([self.activeViewController stackedNavigationPageSize] == kStackedPageFullSize) {
        return @[self.activeViewController];
    }

    NSInteger otherVisibleIndex = activeIndex + (self.activeViewControllerPagePosition == SPStackedNavigationPagePositionLeft ? 1 : -1);
    NSRange range;
    range.location = otherVisibleIndex >= 0 ? MIN(otherVisibleIndex, activeIndex) : activeIndex;
    range.length = (otherVisibleIndex >= 0 && otherVisibleIndex < [[self viewControllers] count]) ? 2 : 1;

    return [[self viewControllers] subarrayWithRange:range];
}
- (NSArray*)viewControllers; { return [self childViewControllers]; }
- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSMutableArray *vcs = [NSMutableArray array];
    while(self.viewControllers.count > 0 && self.viewControllers.lastObject != viewController)
        [vcs addObject:[self popViewControllerAnimated:animated]];
    return vcs;
}
- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    int targetCount = 1;
    if (self.viewControllers.count > 0 && [(self.viewControllers)[0] stackedNavigationPageSize] == kStackedPageHalfSize)
        targetCount = 2;
    
    NSMutableArray *vcs = [NSMutableArray array];
    while(self.viewControllers.count > targetCount)
        [vcs addObject:[self popViewControllerAnimated:animated]];
    [self setActiveViewController:(self.viewControllers)[0] position:SPStackedNavigationPagePositionLeft animated:animated completion:nil];
    return vcs;
}

//- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion
//{
//    int targetCount = 1;
//    if (self.viewControllers.count > 0 && [(self.viewControllers)[0] stackedNavigationPageSize] == kStackedPageHalfSize)
//        targetCount = 2;
//    
//    NSMutableArray *vcs = [NSMutableArray array];
//    while(self.viewControllers.count > targetCount)
//        [vcs addObject:[self popViewControllerAnimated:animated]];
//    [self setActiveViewController:(self.viewControllers)[0] position:SPStackedNavigationPagePositionLeft animated:animated];
//    return vcs;
//}

-(void)setCardVisibilities
{
    NSArray *visibleCards = [self visibleViewControllers];

    for (int i = 0; i < [[self viewControllers] count]; i++)
    {
        UIViewController *card = [self.viewControllers objectAtIndex:i];

        if ([visibleCards containsObject:card])
        {
            [self.view addSubview:card.view];
        }
        else
        {
            [card.view removeFromSuperview];
        }
    }
}

- (UIViewController*)topViewController
{
    return self.viewControllers.lastObject;
}
- (UIGestureRecognizer*)panGestureRecognizer
{
    (void)self.view; // make sure we're loaded
    return [_scroll panGestureRecognizer];
}

#pragma mark VC integration
- (UITabBarItem*)tabBarItem
{
    return self.viewControllers.count==0?nil:[(self.viewControllers)[0] tabBarItem];
}

#pragma KVC
- (NSSet*)keyPathsForValuesAffectingTabBarItem
{
    return [NSSet setWithObject:@"viewControllers"];
}
- (NSSet*)keyPathsForValuesAffectingTopViewController
{
    return [NSSet setWithObject:@"viewControllers"];
}
- (NSSet*)keyPathsForValuesAffectingVisibleViewController
{
    return [NSSet setWithObject:@"viewControllers"];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


#pragma mark Scroll delegate
- (void)stackedNavigationScrollView:(SPStackedNavigationScrollView *)stackedNavigationScrollView
             didStopAtPageContainer:(SPStackedPageContainer *)stackedPageContainer
                       pagePosition:(SPStackedNavigationPagePosition)pagePosition
{
    [self setActiveViewController:stackedPageContainer.vc position:pagePosition];
}

@end


@implementation UIViewController (SPStackedNavigationControllerItem)
- (SPStackedNavigationController*)stackedNavigationController
{
	id parent = self.parentViewController;
	if([parent isKindOfClass:[SPStackedNavigationController class]])
		return parent;
	return nil;
}

- (void)viewDidBecomeActiveInStackedNavigation { } // Default implementation does nothing

- (void)viewDidBecomeInactiveInStackedNavigation { } // Default implementation does nothing

- (void)activateInStackedNavigationAnimated:(BOOL)animated
{
    [self.stackedNavigationController setActiveViewController:self animated:animated completion:nil];
}

- (BOOL)isActiveInStackedNavigation
{
    return (self.stackedNavigationController.activeViewController == self);
}

@end

@implementation NSObject (SPStackedNavigationChild)
- (SPStackedNavigationPageSize)stackedNavigationPageSize
{
    return kStackedPageFullSize;
}
@end

@implementation UINavigationController (SPStackedNavigationControllerCompatibility)
- (void)pushViewController:(UIViewController *)viewController onTopOf:(UIViewController*)parent animated:(BOOL)animated
{
    [self popToViewController:parent animated:animated];
    [self pushViewController:viewController animated:animated];
}
@end
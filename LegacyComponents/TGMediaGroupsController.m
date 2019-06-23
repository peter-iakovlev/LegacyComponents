#import "TGMediaGroupsController.h"
#import "TGMediaGroupCell.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGMediaAssetMomentList.h>

#import "TGMediaAssetsPickerController.h"
#import "TGMediaAssetsMomentsController.h"

#import <LegacyComponents/TGMediaPickerToolbarView.h>

@interface TGMediaGroupsController () <UITableViewDataSource, UITableViewDelegate>
{
    TGMediaAssetsControllerIntent _intent;
    TGMediaAssetsLibrary *_assetsLibrary;
    NSArray *_groups;
    
    SMetaDisposable *_groupsDisposable;
    
    UITableView *_tableView;
    UIActivityIndicatorView *_indicatorView;
}
@end

@implementation TGMediaGroupsController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary intent:(TGMediaAssetsControllerIntent)intent
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _assetsLibrary = assetsLibrary;
        _intent = intent;
        
        [self setTitle:TGLocalized(@"SearchImages.Title")];
    }
    return self;
}

- (void)dealloc
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    [_groupsDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = self.pallete != nil ? self.pallete.backgroundColor : [UIColor whiteColor];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    if (iosMajorVersion() >= 11)
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _tableView.alwaysBounceVertical = true;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = self.view.backgroundColor;
    _tableView.delaysContentTouches = true;
    _tableView.canCancelContentTouches = true;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];

    _indicatorView = [[UIActivityIndicatorView alloc] init];
    _indicatorView.color = self.pallete.secondaryTextColor;
    _indicatorView.frame = self.view.bounds;
    [self.view addSubview:_indicatorView];
    
    self.scrollViewsForAutomaticInsetsAdjustment = @[ _tableView ];
    
    self.explicitTableInset = UIEdgeInsetsMake(0, 0, TGMediaPickerToolbarHeight, 0);
    self.explicitScrollIndicatorInset = self.explicitTableInset;
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)loadViewIfNeeded
{
    if (iosMajorVersion() >= 9)
    {
        [super loadViewIfNeeded];
    }
    else
    {
        if (![self isViewLoaded])
        {
            [self loadView];
            [self viewDidLoad];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    __weak TGMediaGroupsController *weakSelf = self;
    _groupsDisposable = [[SMetaDisposable alloc] init];
    [_indicatorView startAnimating];

    [_groupsDisposable setDisposable:[[[_assetsLibrary assetGroups] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        __strong TGMediaGroupsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return ;
        
        strongSelf->_groups = next;
        [strongSelf->_tableView reloadData];
        [strongSelf->_indicatorView stopAnimating];
        [strongSelf->_indicatorView setHidden:YES];
        
        if (!strongSelf.viewControllerHasEverAppeared && next.count > 0)
        {
            [strongSelf->_tableView layoutIfNeeded];
            
            for (TGMediaGroupCell *cell in strongSelf->_tableView.visibleCells)
            {
                if (cell.assetGroup.isCameraRoll)
                {
                    [strongSelf->_tableView selectRowAtIndexPath:[strongSelf->_tableView indexPathForCell:cell] animated:false scrollPosition:UITableViewScrollPositionNone];
                }
            }
        }
        else if ([strongSelf.navigationController isKindOfClass:[TGMediaAssetsController class]])
        {
            TGMediaAssetsPickerController *pickerController = ((TGMediaAssetsController *)strongSelf.navigationController).pickerController;
            if (![next containsObject:pickerController.assetGroup])
                [strongSelf.navigationController popToRootViewControllerAnimated:false];
        }
    }]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_tableView.indexPathForSelectedRow != nil)
        [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:true];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.navigationController.viewControllers.count > 1 && _tableView.indexPathForSelectedRow == nil)
    {
        TGMediaAssetsPickerController *controller = self.navigationController.viewControllers.lastObject;
        if ([controller isKindOfClass:[TGMediaAssetsPickerController class]])
        {
            for (TGMediaGroupCell *cell in _tableView.visibleCells)
            {
                if ([cell.assetGroup isEqual:controller.assetGroup])
                {
                    NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
                    if (indexPath != nil)
                        [_tableView selectRowAtIndexPath:indexPath animated:false scrollPosition:UITableViewScrollPositionNone];
                }
            }
        }
    }
}

#pragma mark - Table View Data Source & Delegate

- (void)tableView:(UITableView *)__unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id group = _groups[indexPath.row];
    
    if (self.openAssetGroup != nil)
        self.openAssetGroup(group);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGMediaGroupCell *cell = [tableView dequeueReusableCellWithIdentifier:TGMediaGroupCellKind];
    if (cell == nil)
        cell = [[TGMediaGroupCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGMediaGroupCellKind];
    cell.pallete = self.pallete;
    
    id group = _groups[indexPath.row];
    
    if ([group isKindOfClass:[TGMediaAssetMomentList class]])
        [cell configureForMomentList:group];
    else if ([group isKindOfClass:[TGMediaAssetGroup class]])
        [cell configureForAssetGroup:group];
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _groups.count;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return TGMediaGroupCellHeight;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    return 0.001f;
}

- (UIView *)tableView:(UITableView *)__unused tableView viewForFooterInSection:(NSInteger)__unused section
{
    return [[UIView alloc] init];
}

- (BOOL)prefersStatusBarHidden
{
    if (iosMajorVersion() >= 7)
    {
        if (self.navigationController != nil)
            return self.navigationController.prefersStatusBarHidden;
    }
    
    return false;
}

@end

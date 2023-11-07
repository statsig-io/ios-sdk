#import "PerfOnDeviceEvaluationsViewControllerObjC.h"
#import "StatsigSamples-Swift.h"

@import Statsig;


static NSString * const CellIdentifier = @"Cell";

@interface PerfOnDeviceEvaluationsViewControllerObjC() <UICollectionViewDataSource, UICollectionViewDelegate>

@end

@implementation PerfOnDeviceEvaluationsViewControllerObjC {
    UICollectionView *_collectionView;
    NSInteger _numCells;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupCollectionView];


    [Statsig
     startWithSDKKey:Constants.CLIENT_SDK_KEY completion:^(NSString * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error %@", error);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self load];
        });
    }];
}

- (void)load {
    _numCells = 9999;
    [_collectionView reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _numCells;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];

    BOOL gate = [Statsig checkGateForName:@"partial_gate"];

    if (gate) {
        cell.backgroundColor = [UIColor systemGreenColor];
    } else {
        cell.backgroundColor = [UIColor systemRedColor];
    }

    return cell;
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout =
    [[UICollectionViewFlowLayout alloc] init];
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);

    _collectionView =
    [[UICollectionView alloc]
     initWithFrame:self.view.bounds
     collectionViewLayout:layout];

    _collectionView.dataSource = self;
    [_collectionView
     registerClass:[UICollectionViewCell class]
     forCellWithReuseIdentifier:CellIdentifier
    ];

    [self.view addSubview:_collectionView];
}

@end

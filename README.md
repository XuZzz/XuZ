# 逅逅开发笔记

##添加引导图
####guideView：

```
#import <UIKit/UIKit.h>

@interface GuideView : UIScrollView<UIScrollViewDelegate>
@property (nonatomic, assign) BOOL isOut;
@end
```

```
#import "GuideView.h"

/**
 *  引导页张数
 */
#define DEF_GUIDE_COUNT 3

@implementation GuideView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.isOut = NO;
        self.bounces=NO;
        self.contentSize = CGSizeMake(self.frame.size.width*3,self.frame.size.height);
        self.backgroundColor = [UIColor blackColor];
        self.showsHorizontalScrollIndicator = NO;
        self.pagingEnabled = YES;
        self.delegate=self;
        self.bounces = YES;
        self.backgroundColor = [UIColor clearColor];
        
        for (int i=0; i<DEF_GUIDE_COUNT; i++)
        {
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(SCREEN_WIDTH*i, 0, SCREEN_WIDTH,SCREEN_HEIGHT)];
            [imageView setBackgroundColor:LRRandomColor];
            [imageView setImage:[UIImage imageNamed:[NSString stringWithFormat:@"Guide%d.png",i+1]]];
            [self addSubview:imageView];
        }
    }
    return self;
}
-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if (scrollView.contentOffset.x>self.frame.size.width*2+30) {
        [UIView animateWithDuration:1.0 animations:^{
            self.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
        
    }
}

```
AppDelegate.m：

```
#import "GuideView.h"
@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // 2017.6.16
    
    
    
    [self getCityList];
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    manager.shouldResignOnTouchOutside = YES;
    manager.enableAutoToolbar = NO;
    
    [SMSSDK registerApp:appkey withSecret:app_secrect];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    HCTabBarController *tab = [[HCTabBarController alloc] init];
    self.window.rootViewController = tab;
    [self.window makeKeyAndVisible];
    if (![DEF_PERSISTENT_GET_OBJECT(@"showGuide") boolValue])
    {
        DEF_PERSISTENT_SET_OBJECT([NSNumber numberWithBool:YES], @"showGuide");
        GuideView *guide = [[GuideView alloc] initWithFrame:self.window.bounds];
        [self.window addSubview:guide];
    }

    
    return YES;
}
```
####使用KVC修改textfield.placeholder

```
textField.placeholder = @"username is in here!";  
[textField setValue:[UIColor redColor] forKeyPath:@"_placeholderLabel.textColor"];
```


#####获取验证码倒计时
```
// 获取验证码倒计时
- (void)receiveCheckNumButton:(UIButton *)sender{
    
    __block int timeout = 60; //倒计时时间
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
    dispatch_source_set_timer(_timer,dispatch_walltime(NULL, 0),1.0*NSEC_PER_SEC, 0); //每秒执行
    dispatch_source_set_event_handler(_timer, ^{
        
        if(timeout <= 0){ //倒计时结束，关闭
            dispatch_source_cancel(_timer);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                //设置界面的按钮显示 根据自己需求设置
                [sender setTitle:@"重新获取" forState:UIControlStateNormal];
                sender.userInteractionEnabled = YES;
                sender.backgroundColor = [UIColor purpleColor];
            });
            
        }else{
            
            int seconds = timeout;
            
            NSString *strTime = [NSString stringWithFormat:@"%.2d", seconds];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //让按钮变为不可点击的灰色
                
                sender.backgroundColor = [UIColor lightGrayColor];
                
                sender.userInteractionEnabled = NO;
                
                //设置界面的按钮显示 根据自己需求设置
                
                [UIView beginAnimations:nil context:nil];
                
                [UIView setAnimationDuration:1];
                
                [sender setTitle:[NSString stringWithFormat:@"%@s",strTime] forState:UIControlStateNormal];
                
                [UIView commitAnimations];
            });
            timeout--;
        }
        
    });
    dispatch_resume(_timer);
}

```
###### 沙盒存取文件

```
- (void)saveArray  
{  
    // 1.获得沙盒根路径  
    NSString *home = NSHomeDirectory();  
      
    // 2.document路径  
    NSString *docPath = [home stringByAppendingPathComponent:@"Documents"];  
      
    // 3.新建数据  
//    MJPerson *p = [[MJPerson alloc] init];  
//    p.name = @"rose";  
    NSArray *data = @[@"jack", @10, @"ffdsf"];  
      
      
    NSString *filepath = [docPath stringByAppendingPathComponent:@"data.plist"];  
      
      
    [data writeToFile:filepath atomically:YES];  
}  
  
- (IBAction)read {  
    // 1.获得沙盒根路径  
    NSString *home = NSHomeDirectory();  
      
    // 2.document路径  
    NSString *docPath = [home stringByAppendingPathComponent:@"Documents"];  
      
    // 3.文件路径  
    NSString *filepath = [docPath stringByAppendingPathComponent:@"data.plist"];  
      
    // 4.读取数据  
    NSArray *data = [NSArray arrayWithContentsOfFile:filepath];  
    NSLog(@"%@", data);  
}
```


######根据城市/省份编码找打plist中对应的城市/省份名 
```

if (dataM.peopleUserProvince != nil || dataM.peopleUserProvince != 0) {
        self.peopleUserProvince = [dataM.peopleUserProvince integerValue];
        for (int i = 0; i < _addressArray.count; i ++) {//1. 循环plist中的数据
            NSDictionary *province = [[_addressArray objectAtIndex:i] objectForKey:@"province"]; // 2.取出_addressArray[i]中的省份（字典）
            NSNumber *provinceCode = [province objectForKey:@"provinceCode"]; // 3.取出省份编码
            if (provinceCode == [NSNumber numberWithInteger:self.peopleUserProvince]) { // 4.判断省份编码是否与model中的相等
                NSString *provinceName =[province objectForKey:@"provinceName"]; // 5.如果相等，取出省份名
                
                if ([[_addressArray objectAtIndex:i] objectForKey:@"city"] != nil && dataM.peopleUserCity != 0) { // 6.准备取城市名，先判断城市列表是否为空
                    self.peopleUserCity = [dataM.self.peopleUserCity integerValue];
                    NSArray *city =[[_addressArray objectAtIndex:i] objectForKey:@"city"]; // 7.不为空取出城市列表(数组)
                    for (int i = 0; i <city.count; i++) { // 8.循环城市列表
                        NSDictionary *cityDict = [city objectAtIndex:i]; // 9.取出城市列表中city[i]的元素，准备判断
                        NSNumber *cityCode = [cityDict objectForKey:@"cityCode"];  // 10.取出城市code
                        if (cityCode == [NSNumber numberWithInteger:self.peopleUserCity]) { // 11.判断城市编码是否与model中的相等
                            NSString *cityName = [cityDict objectForKey:@"cityName"]; // 12. 若相等，取出城市名
                            _cellAddress = [NSString stringWithFormat:@"%@-%@",provinceName,cityName]; // 13.给cellAddress赋值
                            break; // 找出来 跳出循环
                        }
                    }
                }
                else{
                    _cellAddress = provinceName;
                    break;
                }
            }
        }
    }
```

###### 使用SDWebimage加载图片后进行操作

```
NSString *url = @"";
[imageView sd_setImageWithURL:url placeholderImage:[UIImage imageNamed:@" "] completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
    }];
```

######RAC

```
[self.loginView.thirdView reciveButtonClickBlock:^(UIButton * sender) {
        
        UmSocialLocalManager *manager = [UmSocialLocalManager defaultManager];
        
        @weakify(self)
        
        [[[manager getAuthWithUserInfoFromButton:sender.tag]
          
         map:^UMSocialUserInfoResponse *(UMSocialUserInfoResponse * result) {
             
             return result;
         }]
         subscribeNext:^(UMSocialUserInfoResponse *result) {
             
            @strongify(self)
             
            self.responseResult = result;
             
             if (self.responseResult != nil) {
                 [self loginSuccess];
             }
             
            NSLog(@"%@",self.responseResult);
         }
         error:^(NSError *error) {
            
             NSLog(@"Error : %@",error);
         }];
        
    }];
```


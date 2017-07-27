//
//  RWSearchFormViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 02/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "RWSearchFormViewController.h"
#import "RWSearchResultsViewController.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <ReactiveCocoa/RACEXTScope.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "RWTweet.h"
#import <LinqToObjectiveC/NSArray+LinqExtensions.h>


typedef NS_ENUM(NSInteger , RWTwitterInstantError){
    RWTwitterInstantErrorAccessDenied,
    RWTwitterInstantErrorNoTwitterAccounts,
    RWTwitterInstantErrorInvalidResponse
};

static NSString * const RWTwitterInstantDomain = @"TwitterInstant";

@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;

@property (strong, nonatomic) ACAccountStore *accountStore; // ACAccountsStore类能让你访问你的设备能连接到的多个社交媒体账号

@property (strong, nonatomic) ACAccountType *twitterAccountType; //ACAccountType类则代表账户的类型。

@end

@implementation RWSearchFormViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.resultsViewController = [[RWSearchResultsViewController alloc] init];
  
    self.title = @"Twitter Instant";
  
    [self styleTextField:self.searchText];
    
    @weakify(self);
    
    RAC(self.searchText , backgroundColor) = [RACSubject combineLatest:@[self.searchText.rac_textSignal] reduce:^UIColor *(NSString *text){
       
        @strongify(self);
        
        return [self isValidSearchText:text] ? [UIColor whiteColor] : [UIColor yellowColor];
    }];
    
    self.accountStore = [[ACAccountStore alloc] init];
    self.twitterAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    //应用应该等待获取访问Twitter权限的signal发送completed事件，然后再订阅text field的signal
    [[[[[[self requestAccessToTwitterSignal]
    then:^RACSignal *{
        
        @strongify(self);
        
        return self.searchText.rac_textSignal;
        
    }]
    filter:^BOOL(NSString *text) {
    
        // 过滤
        // 当输入的字符小于3的时候不会接收到信号
        @strongify(self)
        
        return [self isValidSearchText:text];
    }]
    flattenMap:^RACStream *(NSString* text) {
     // map指的是信号 但是仅仅只是一个的信号。
     // 我们需要的是请求结果的信号 使用flattenMap 来获得信号中的信号
        @strongify(self);
        
        return [self signalForSearchText:text];
    }]
    deliverOn:[RACScheduler mainThreadScheduler]] // 刷新UI用
    subscribeNext:^(NSDictionary * jsonSearchResult) {
        NSLog(@"%@",jsonSearchResult);
        NSArray *statuses = jsonSearchResult[@"statuses"];
        NSArray *tweets = [statuses linq_select:^id(id tweet) {
            return [RWTweet tweetWithStatus:tweet];
        }];
        [self.resultsViewController displayTweets:tweets];
    }error:^(NSError *error) {
        
        NSLog(@"An error occurred: %@", error);
        
    }];
    
}
// 应用获取访问社交媒体账号的权限时，会弹出提示框，这是一个异步请求，封装进一个signal是一个好选择

- (RACSignal *)requestAccessToTwitterSignal{
    
    // 1 define an error
    NSError *accessError = [NSError errorWithDomain:RWTwitterInstantDomain
                                               code:RWTwitterInstantErrorAccessDenied
                                           userInfo:nil];
    
    
    // 2 creat the signal
    
    @weakify(self)
    
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self)
        
        [self.accountStore requestAccessToAccountsWithType:self.twitterAccountType options:nil completion:^(BOOL granted, NSError *error) {
            // handle the response
            if (!granted) {
                [subscriber sendError:accessError];
            }
            else{
                [subscriber sendNext:nil];
                [subscriber sendCompleted];
            }
        }];
        return  nil;
    }];
    
}
- (SLRequest *)requestforTwitterSearchWithText:(NSString *)text{
    
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
    
    NSDictionary *paramas = @{@"q" : text};
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:paramas];
    
    return request;
}

// 为上一个方法（请求方法）创建signal

- (RACSignal *)signalForSearchText:(NSString *)text{
    
    // 1 define error
    
    NSError *noAccountError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorNoTwitterAccounts userInfo:nil]; // 查无此人错误
    
    NSError *invalidRequestError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorInvalidResponse userInfo:nil]; // 请求不好使错误
    
    // creat signal block
    
    @weakify(self)
    
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        @strongify(self)
        
        // creat the request
        
        SLRequest *request = [self requestforTwitterSearchWithText:text];
        
        // supply a twitter account
        
        NSArray *twitterAccounts = [self.accountStore accountsWithAccountType:self.twitterAccountType];
        
        if (twitterAccounts.count == 0) {
            
            [subscriber sendError:noAccountError];
        }
        else{
            
            [request setAccount:twitterAccounts.lastObject];
            
            // perform the request
            [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
               
                
                if (urlResponse.statusCode == 200) {
                    
                    // success
                    NSDictionary *timeLineData = [NSJSONSerialization
                                                    JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
                    
                    [subscriber sendNext:timeLineData];
                    
                    [subscriber sendCompleted];
                    
                }
                else{
                    
                    // send request error
                    [subscriber sendError:invalidRequestError];
                }
                
            }];
        }
        
        return nil;
        
    }];
}

- (BOOL)isValidSearchText:(NSString *)text{
    
    return text.length > 2;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    [self.searchText resignFirstResponder];
}

- (void)styleTextField:(UITextField *)textField {
  CALayer *textFieldLayer = textField.layer;
  textFieldLayer.borderColor = [UIColor grayColor].CGColor;
  textFieldLayer.borderWidth = 2.0f;
  textFieldLayer.cornerRadius = 0.0f;
}

@end

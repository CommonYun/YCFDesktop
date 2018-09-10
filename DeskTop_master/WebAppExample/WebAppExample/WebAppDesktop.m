//
//  WebAppDesktop.m
//  WebAppExample
//
//  Created by LiHongli on 15/8/19.
//  Copyright (c) 2015年 李红力-易到用车iOS开发工程师. All rights reserved.
//

/***
 *
 http://www.open-open.com/code/view/1421907845515
 技术原理： 在iOS开发中可以使用openUrl的方式打开一个网页，并通过Safari浏览器的发送到主屏幕从而创建一个网页的快捷方式，这篇文章就是利用这个方 法来创建一个app的桌面快捷方式。首先在app内部开启一个轻量级的HttpServer，利用openurl：127.0.0.1 的方式打开本地页面，利用html的重定向将页面指向一个包含创建桌面快捷方式所有信息的，遵守data协议的url，这时利用Safari的发送到主屏 幕，就可以达到我们的要求。
 
 技术难点：
 
 1. 创建一个本地的httpServer。2. 创建本地页面以及data协议url时的编码格式。3. 在Safari未启动时或者app进入后台时，本地httpserver服务启动延迟。
 */


#import "WebAppDesktop.h"
#import <CocoaHTTPServer/CocoaHTTPServer-umbrella.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@implementation DesktopModel



@end




@interface WebAppDesktop()

@property (nonatomic, strong) NSString *webRootDir;
@property (nonatomic, strong) NSString *mainPage;
@property (nonatomic, strong) HTTPServer *httpServer;

@end

@implementation WebAppDesktop

- (instancetype)init {
    if (self = [super init]) {
        
        //启动本地httpSever和服务器首页页面
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = paths[0];
        self.webRootDir = [documentsPath stringByAppendingPathComponent:@"web"];
        BOOL isDirectory = YES;
        BOOL exsit = [[NSFileManager defaultManager] fileExistsAtPath:_webRootDir isDirectory:&isDirectory];
        if(!exsit){
            [[NSFileManager defaultManager] createDirectoryAtPath:_webRootDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        // data保存路径
        self.mainPage = [NSString stringWithFormat:@"%@/web/index.html",documentsPath];
        
        
//        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        _httpServer = [[HTTPServer alloc] init];
        [_httpServer setType:@"_http._tcp."];
        
        [_httpServer setDocumentRoot:_webRootDir];
        
        NSError *error;
        if([_httpServer start:&error]){
            NSLog(@"Started HTTP Server on port %hu", [_httpServer listeningPort]);
        }
        else{
            NSLog(@"Error starting HTTP Server: %@", error);
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
    }
    return self;
}


+ (instancetype)shareInstanced{
    static WebAppDesktop *desktop = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (desktop == nil) {
            desktop = [[WebAppDesktop alloc] init];
        }
    });
    return desktop;
}

/*****
 *  进入后台， 关闭httpserver
 */
- (void)applicationDidEnterBackground:(UIApplication *)application{
    if([[UIDevice currentDevice].systemVersion integerValue] >= 6.0){
        sleep(1);
    }else {
        sleep(2);
    }
    [_httpServer stop];
}

/******
 * 进入前台时，如果httpserver 未启动，则启动
 */
- (void)applicationWillEnterForeground:(UIApplication *)application{
    NSError *error;
    if(![_httpServer isRunning]){
        if([_httpServer start:&error])
        {
            NSLog(@"Started HTTP Server on port %hu", [_httpServer listeningPort]);
        }
        else
        {
            NSLog(@"Error starting HTTP Server: %@", error);
        }
    }
}

/*****
 *
 * 创建数据，并调起Safari
 */
- (void)setObject:(DesktopModel *)model{
    NSString *title = model.title;
    NSString *urlScheme = model.urlScheme;
    NSString *moduleID = model.moduleID;
    NSString *imageName = model.imageName;
    
    
    NSMutableString *htmlStr = [[NSMutableString alloc] init];
    [htmlStr appendString:@"<html><head>"];
    [htmlStr appendString:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"];
    
    NSMutableString *taragerUrl = [NSMutableString stringWithFormat:@"0;url=data:text/html;charset=UTF-8,<html><head><meta content=\"yes\" name=\"apple-mobile-web-app-capable\" /><meta content=\"text/html; charset=UTF-8\" http-equiv=\"Content-Type\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, user-scalable=no\" /><title>%@</title></head><body bgcolor=\"#ffffff\">",title];
    
    NSString *htmlUrlScheme = [NSString stringWithFormat:@"<a href=\"%@",urlScheme];
    
    NSString *dataUrlStr = nil;
    
    dataUrlStr =  [NSString stringWithFormat:@"%@=%@&%@=%@\" id=\"qbt\" style=\"display: none;\"></a>",@"10000",moduleID,@"1",@(1)];
    
    UIImage *image = [UIImage imageNamed:imageName];
    NSData *imageData = UIImagePNGRepresentation(image);
    
    NSString *base6ImageStr = [imageData base64EncodedStringWithOptions:0];
    
    NSString *imageUrlStr = [NSString stringWithFormat:@"<span id=\"msg\"></span></body><script>if (window.navigator.standalone == true) {    var lnk = document.getElementById(\"qbt\");    var evt = document.createEvent('MouseEvent');    evt.initMouseEvent('click');    lnk.dispatchEvent(evt);}else{    var addObj=document.createElement(\"link\");    addObj.setAttribute('rel','apple-touch-icon-precomposed');    addObj.setAttribute('href','data:image/png;base64,%@');",base6ImageStr];
    
    NSString *lastHtmlStr = @"document.getElementsByTagName(\"head\")[0].appendChild(addObj);    document.getElementById(\"msg\").innerHTML='<div style=\"font-size:12px;\">点击页面下方的 + 或 <img id=\"i\" src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAMAAAC6V+0/AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNiAoV2luZG93cykiIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6OTU1NEJDMzMwQTBFMTFFM0FDQTA4REMyNUE4RkExNkEiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6OTU1NEJDMzQwQTBFMTFFM0FDQTA4REMyNUE4RkExNkEiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo5NTU0QkMzMTBBMEUxMUUzQUNBMDhEQzI1QThGQTE2QSIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo5NTU0QkMzMjBBMEUxMUUzQUNBMDhEQzI1QThGQTE2QSIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PlMy2ugAAAAbUExUReXy/yaS/4nE/67W//n8/+n0/0yl/wB//////1m3cVcAAAAJdFJOU///////////AFNPeBIAAABDSURBVHjaxNA7DgAgCAPQoiLc/8T+EgV1p0ubxwb0E+xR8SBICBcyJUnEHktW0VwOykivvSaus6kA1CD0sZ+3aQIMAJIgC+S9X9jmAAAAAElFTkSuQmCC\"> 按钮，在弹出的菜单中选择［添加至主屏幕］，即可将选定的功能添加到主屏幕作为快捷方式。</div>';}</script></html>";
    
    [taragerUrl appendString:htmlUrlScheme];
    [taragerUrl appendString:dataUrlStr];
    
    // 转码
    // 方法一
    //  dataUrlStr = [dataUrlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    // 方法2
    NSString *dataUrlEncode = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)taragerUrl, nil, nil, kCFStringEncodingUTF8));
    NSString *imageUrlEncode =  (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)imageUrlStr, nil, nil, kCFStringEncodingUTF8));
    NSString *lastHtmlStrEncode = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)lastHtmlStr, nil, nil, kCFStringEncodingUTF8));
    
    [htmlStr appendFormat:@"<meta http-equiv=\"REFRESH\" content=\"%@%@%@\">",dataUrlEncode,imageUrlEncode,lastHtmlStrEncode];
    [htmlStr appendString:@"</head></html>"];
    
    NSData *data = [htmlStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [data writeToFile:_mainPage atomically:YES];
    
    NSString *urlStrWithPort = [NSString stringWithFormat:@"http://127.0.0.1:%d",[_httpServer listeningPort]];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStrWithPort]];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

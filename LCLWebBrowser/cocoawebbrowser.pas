unit CocoaWebBrowser;

{
  LCL Web browser control.

  Author:    Phil Hess.
  Copyright: Copyright (C) Phil Hess.
  License:   Modified LGPL (see Free Pascal's rtl/COPYING.FPC).

  Docs: https://developer.apple.com/documentation/webkit/webview
}

{$mode objfpc}{$H+}
{$modeswitch objectivec1}

interface

uses
  SysUtils,
  CocoaAll,
  WebKit,
  LCLType,
  Controls,
  CocoaPrivate,
  WebBrowser,
  WSWebBrowser;

type
  WebBrowserDelegate = objcclass(NSObject)
  private
    FWbWinControl : TWinControl;
  public
     {Frame load delegate methods}
    procedure webView_didFinishLoadForFrame(sender: WebView; frame: WebFrame); override;
    procedure webView_didFailProvisionalLoadWithError_forFrame(
               sender: WebView; error: NSError; frame: WebFrame); override;
     {User interface delegate methods}
//    function webView_createWebViewWithRequest(
//              sender: WebView; request: NSURLRequest): WebView; override;
     {Policy delegate methods}
    procedure webView_decidePolicyForNewWindowAction_request_newFrameName_decisionListener(
               webView_: WebView; actionInformation: NSDictionary; request: NSURLRequest; 
               frameName: NSString; listener: WebPolicyDecisionListenerProtocol); override;
  end;


  TCocoaWSWebBrowser = class(TWSWebBrowser)
  published
    class function CreateHandle(const AWinControl : TWinControl;
                                const AParams     : TCreateParams): TLCLIntfHandle; override;
    class procedure DestroyHandle(const AWinControl : TWinControl); override;
    class procedure EnableLinkClick(const AWinControl : TWinControl;
                                          ABoolean    : Boolean); override;
    class function LoadPage(const AWinControl : TWinControl;
                            const Url         : string) : Boolean; override;
    class function LoadPageFromHtml(const AWinControl : TWinControl;
                                    const Html        : string;
                                    const RelativeUrl : string = '') : Boolean; override;
    class function EvaluateJavaScript(const AWinControl : TWinControl;
                                      const Script      : string) : string; override;
  end;


implementation

type
  TIntCustomWebBrowser = class(TCustomWebBrowser);  //so we can access protected methods


procedure WebBrowserDelegate.webView_didFinishLoadForFrame(sender: WebView; frame: WebFrame);
begin
  TIntCustomWebBrowser(FWbWinControl).DoPageLoaded;
end;

procedure WebBrowserDelegate.webView_didFailProvisionalLoadWithError_forFrame(
                              sender: WebView; error: NSError; frame: WebFrame);
begin
  TIntCustomWebBrowser(FWbWinControl).DoPageLoadError;
end;

(*
function WebBrowserDelegate.webView_createWebViewWithRequest(
                             sender: WebView; request: NSURLRequest): WebView;
begin  //doesn't work - request is always nil; http://trac.webkit.org/changeset/75349/webkit
  Result := nil;
  if Assigned(TIntCustomWebBrowser(FWbWinControl).OnLinkClick) then
    TIntCustomWebBrowser(FWbWinControl).DoLinkClick(request.URL.absoluteString.UTF8String);
end;
*)

procedure WebBrowserDelegate.webView_decidePolicyForNewWindowAction_request_newFrameName_decisionListener(
                              webView_: WebView; actionInformation: NSDictionary; request: NSURLRequest; 
                              frameName: NSString; listener: WebPolicyDecisionListenerProtocol);
begin
  if Assigned(TIntCustomWebBrowser(FWbWinControl).OnLinkClick) then
    TIntCustomWebBrowser(FWbWinControl).DoLinkClick(request.URL.absoluteString.UTF8String);
end;



class function TCocoaWSWebBrowser.CreateHandle(const AWinControl : TWinControl;
                                               const AParams     : TCreateParams): TLCLIntfHandle;
var
  AWebView     : WebView;
  AWebDelegate : WebBrowserDelegate;
begin
  AWebView := WebView(NSView(WebView.alloc).lclInitWithCreateParams(AParams));

  AWebDelegate := WebBrowserDelegate.alloc.init;
  AWebDelegate.FWbWinControl := AWinControl;
  AWebView.setFrameLoadDelegate(AWebDelegate);
//  AWebView.setUIDelegate(AWebDelegate);

  Result := TLCLIntfHandle(AWebView);
end;


class procedure TCocoaWSWebBrowser.DestroyHandle(const AWinControl : TWinControl);
begin
  if not AWinControl.HandleAllocated then
    Exit;
  WebView(AWinControl.Handle).frameLoadDelegate.release;
  NSObject(AWinControl.Handle).release;
end;


class procedure TCocoaWSWebBrowser.EnableLinkClick(const AWinControl : TWinControl;
                                                         ABoolean    : Boolean);
begin
  if ABoolean then
    WebView(AWinControl.Handle).setPolicyDelegate(
     WebView(AWinControl.Handle).frameLoadDelegate)  {Same object used for both}
  else
    WebView(AWinControl.Handle).setPolicyDelegate(nil);
end;


class function TCocoaWSWebBrowser.LoadPage(const AWinControl : TWinControl;
                                           const Url         : string) : Boolean;
var
  ANSURL : NSURL;
  ANSReq : NSURLRequest;
begin
  ANSURL := NSURL.URLWithString(
             NSSTR(PAnsiChar(Url)).
              stringByAddingPercentEscapesUsingEncoding(NSASCIIStringEncoding));
  ANSReq := NSURLRequest.RequestWithURL(ANSURL);
  WebView(AWinControl.Handle).mainFrame.loadRequest(ANSReq);
  Result := True;
end;


class function TCocoaWSWebBrowser.LoadPageFromHtml(const AWinControl : TWinControl;
                                                   const Html        : string;
                                                   const RelativeUrl : string = '') : Boolean;
var
  ANSURL : NSURL;
begin
  ANSURL := nil;
  if RelativeUrl <> '' then
    ANSURL := NSURL.URLWithString(
               NSSTR(PAnsiChar(RelativeUrl)).
                stringByAddingPercentEscapesUsingEncoding(NSASCIIStringEncoding));
  WebView(AWinControl.Handle).mainFrame.loadHTMLString_baseURL(NSSTR(PAnsiChar(Html)), ANSURL);
  Result := True;
end;


class function TCocoaWSWebBrowser.EvaluateJavaScript(const AWinControl : TWinControl;
                                                     const Script      : string) : string;
 {See https://developer.apple.com/documentation/webkit/webview/
       1408429-stringbyevaluatingjavascriptfrom?language=objc}
begin
  Result := WebView(AWinControl.Handle).stringByEvaluatingJavaScriptFromString(
             NSSTR(PAnsiChar(Script))).UTF8String;
end;


end.

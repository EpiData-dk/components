unit WebBrowser;

{
  LCL Web browser control.

  Author:    Phil Hess.
  Copyright: Copyright (C) Phil Hess.
  License:   Modified LGPL (see Free Pascal's rtl/COPYING.FPC).
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  LResources,
  Controls;

type
  TWbClickLinkEvent = procedure(Sender : TObject;
                                Url    : string) of object;


type
  TCustomWebBrowser = class(TWinControl)
  private
    FOnPageLoaded    : TNotifyEvent;
    FOnPageLoadError : TNotifyEvent;
    FOnLinkClick     : TWbClickLinkEvent;
  protected
    class procedure WSRegisterClass; override;
    procedure CreateWnd; override;
    procedure SetOnLinkClick(AOnLinkClick : TWbClickLinkEvent); virtual;
    procedure DoPageLoaded;
    procedure DoPageLoadError;
    procedure DoLinkClick(const Url : string);
  public
    constructor Create(AOwner : TComponent); override;
    function LoadPage(const Url : string) : Boolean;
    function LoadPageFromHtml(const Html        : string;
                              const RelativeUrl : string = '') : Boolean;
    function EvaluateJavaScript(const Script : string) : string;
    property OnPageLoaded : TNotifyEvent read FOnPageLoaded write FOnPageLoaded;
    property OnPageLoadError : TNotifyEvent read FOnPageLoadError write FOnPageLoadError;
    property OnLinkClick : TWbClickLinkEvent read FOnLinkClick write SetOnLinkClick;
  end;


  TWebBrowser = class(TCustomWebBrowser)
  published
    property Align;
    property Anchors;
    property Constraints;
    property OnLinkClick;
    property OnPageLoaded;
    property OnPageLoadError;
  end;


procedure Register;


implementation

uses
  WebBrowserFactory,
  WSWebBrowser;


constructor TCustomWebBrowser.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);

  ControlStyle := ControlStyle + [csClickEvents, csFramed];  //?

  Height := 140;
  Width := 200;
  TabStop := False;  //?

  FOnPageLoaded := nil;
  FOnPageLoadError := nil;
  FOnLinkClick := nil;  {by default, browser handles clicked links internally
                          if possible; links that need an external browser 
                          (target="_blank") are ignored}
end;


class procedure TCustomWebBrowser.WSRegisterClass;  
begin
  inherited;
  WSRegisterWebBrowser;
end;


procedure TCustomWebBrowser.CreateWnd;
begin
  inherited CreateWnd;
   {Handle created, so okay to finish initializing properties}  
  SetOnLinkClick(FOnLinkClick);
end;


function TCustomWebBrowser.LoadPage(const Url : string) : Boolean;
begin
  Result := False;
  if not HandleAllocated then
    HandleNeeded;
  if HandleAllocated then
    Result := TWSWebBrowserClass(WidgetSetClass).LoadPage(self, Url);
end;


function TCustomWebBrowser.LoadPageFromHtml(const Html        : string;
                                            const RelativeUrl : string = '') : Boolean;
begin
  Result := False;
  if not HandleAllocated then
    HandleNeeded;
  if HandleAllocated then
    Result := TWSWebBrowserClass(WidgetSetClass).LoadPageFromHtml(self, Html, RelativeUrl);
end;


function TCustomWebBrowser.EvaluateJavaScript(const Script : string) : string;
begin  {Returns blank string if can't evaluate script}
  Result := '';
  if not HandleAllocated then
    HandleNeeded;
  if HandleAllocated then
    Result := TWSWebBrowserClass(WidgetSetClass).EvaluateJavaScript(self, Script);
end;


procedure TCustomWebBrowser.SetOnLinkClick(AOnLinkClick : TWbClickLinkEvent);
begin
  FOnLinkClick := AOnLinkClick;
  if HandleAllocated then
    TWSWebBrowserClass(WidgetSetClass).EnableLinkClick(self, Assigned(AOnLinkClick));
end;


procedure TCustomWebBrowser.DoPageLoaded;
begin
  if Assigned(FOnPageLoaded) then
    FOnPageLoaded(self);
end;


procedure TCustomWebBrowser.DoPageLoadError;
begin
  if Assigned(FOnPageLoadError) then
    FOnPageLoadError(self);
end;


procedure TCustomWebBrowser.DoLinkClick(const Url : string);
begin
  if Assigned(FOnLinkClick) then
    FOnLinkClick(self, Url);
end;



procedure Register;
begin
  RegisterComponents('Common Controls', [TWebBrowser]);
end;


initialization
{$I webbrowser.lrs}  //glyph courtesy of https://openclipart.org/detail/35233/tango-inetrnet-web-browser

end.

unit WebBrowserFactory;

{
  LCL Web browser control.

  Author:    Phil Hess.
  Copyright: Copyright (C) Phil Hess.
  License:   Modified LGPL (see Free Pascal's rtl/COPYING.FPC).
}

{$mode objfpc}{$H+}

interface

uses
  WSLCLClasses,
  WebBrowser,
{$IF DEFINED(LCLCocoa)}
  CocoaWebBrowser;
{$ELSEIF DEFINED(LCLQt)}
  QtWebBrowser;
{$ELSE}
  WSWebBrowser;  //for now until other platforms implemented
{$IFEND}

function RegisterWebBrowser : Boolean;


implementation

function RegisterWebBrowser : Boolean; alias : 'WSRegisterWebBrowser';
begin
  Result := True;
{$IF DEFINED(LCLCocoa)}
  RegisterWSComponent(TCustomWebBrowser, TCocoaWSWebBrowser);
{$ELSEIF DEFINED(LCLQt)}
  RegisterWSComponent(TCustomWebBrowser, TQtWSWebBrowser);
{$ELSE}
  RegisterWSComponent(TCustomWebBrowser, TWSWebBrowser);
{$IFEND}
end;


initialization

end.

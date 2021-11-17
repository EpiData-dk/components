unit MainForm;

{
  Main form for PasMap example app.

  With a TWebBrowser control, you can embed not only your own local HTML in
   your app, but also entire Web sites, even Web apps.

  PasMap is the Pascal Lazarus version of the Objective Pascal Xcode app
   (ObjPMap) described here:
   https://macpgmr.github.io/MacXPlatform/WebAppOverview_3.html#EmbeddedBrowser

  Both PasMap and ObjPMap embed the QxMap JavaScript Web app.

  PasMap's icon is based on the location marker used by QxMap:
   https://openlayers.org/api/img/marker.png
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  LCLIntf, WebBrowser;

type
  TLocationRec = record
    LocName : string;
    Lat     : string;
    Lon     : string;
    Display : string;
    end;

const
  QxMapUrl = 'https://macpgmr.github.io/iApps/qxmap/index.html';

  NumLocs = 3;

  Locations : array[1..numLocs] of TLocationRec =
   ((LocName:'Ouray';     Lat:'38.02'; Lon:'-107.67'; Display:'7,792 feet'),
    (LocName:'Silverton'; Lat:'37.81'; Lon:'-107.66'; Display:'9,308 feet'),
    (LocName:'Telluride'; Lat:'37.94'; Lon:'-107.81'; Display:'8,750 feet'));

type
  TMainForm = class(TForm)
    WebBrowser1: TWebBrowser;
    Button1: TButton;
    Label1: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure WebBrowser1PageLoaded(Sender: TObject);
    procedure WebBrowser1PageLoadError(Sender: TObject);
    procedure WebBrowser1LinkClick(Sender: TObject; Url: string);
  private
    function GetMapUrl: string;
    procedure UpdateMap(const UrlStr: string);
  public
  end;

var
  MainFrm: TMainForm;


implementation

{$R *.lfm}

function TMainForm.GetMapUrl: string;
var
  UrlStr : string;
  LocNum : Integer;
begin
  UrlStr := QxMapUrl + '?locations=[';
  for LocNum := 1 to NumLocs do
    begin
    UrlStr := UrlStr + '{"name":"' + locations[LocNum].LocName + '",' +
                        '"lat":' + locations[LocNum].Lat + ',' +
                        '"lon":' + locations[LocNum].Lon + ',' +
                        '"display":"' + locations[LocNum].Display + '"}';
    if LocNum < NumLocs then
      UrlStr := UrlStr + ','
    else
      UrlStr := UrlStr + ']';
    end;
  Result := UrlStr;
end;


procedure TMainForm.UpdateMap(const UrlStr: string);
begin
  WebBrowser1.LoadPage(UrlStr);
end;


procedure TMainForm.Button1Click(Sender: TObject);
begin
  UpdateMap(GetMapUrl);
  Label1.Caption := 'Loading map...';
end;

procedure TMainForm.WebBrowser1PageLoaded(Sender: TObject);
begin
  Label1.Caption := '';
end;


procedure TMainForm.WebBrowser1PageLoadError(Sender: TObject);
begin
  Label1.Caption := 'Error loading';
end;


procedure TMainForm.WebBrowser1LinkClick(Sender: TObject; Url: string);
 {Link clicked that should open external browser}
begin
  OpenURL(Url);
end;


end.

{*_* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

Authors:      Stan Korotky <stasson@orc.ru>
Creation:     05 Mar 2012
Version:      0.01
Description:  Basic websockets server based on TWSocketServer and
              TWSocketClient components, and websockets implementation
              ported from phpws project (http://code.google.com/p/phpws/).
              Derived from TCP server demo V7.02, by Fran�ois PIETTE.
Support:      Use the mailing list twsocket@elists.org
              Follow "support" link at http://www.overbyte.be for subscription.
Legal issues: Copyright (C) 1999-2010 by Fran�ois PIETTE
              Rue de Grady 24, 4053 Embourg, Belgium. Fax: +32-4-365.74.56
              <francois.piette@overbyte.be>

              This software is provided 'as-is', without any express or
              implied warranty.  In no event will the author be held liable
              for any  damages arising from the use of this software.

              Permission is granted to anyone to use this software for any
              purpose, including commercial applications, and to alter it
              and redistribute it freely, subject to the following
              restrictions:

              1. The origin of this software must not be misrepresented,
                 you must not claim that you wrote the original software.
                 If you use this software in a product, an acknowledgment
                 in the product documentation would be appreciated but is
                 not required.

              2. Altered source versions must be plainly marked as such, and
                 must not be misrepresented as being the original software.

              3. This notice may not be removed or altered from any source
                 distribution.

              4. You must register this software by sending a picture postcard
                 to the author. Use a nice stamp and mention your name, street
                 address, EMail address and any comment you like to say.
History:

Mar 05, 2012 v0.01 Initial release of websockets demo for ICS.

 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
unit WebSocketSrv1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  OverbyteIcsIniFiles, StdCtrls, ExtCtrls,
  OverbyteIcsWSocket, OverbyteIcsWSocketS, OverbyteIcsWndControl,
  Socket, interfaces;

const
  TcpSrvVersion = 702;
  CopyRight     = ' WebSocketSrv (c) 2012, Stan Korotky';
  WM_APPSTARTUP = WM_USER + 1;

type

  TWebSocketForm = class(TForm)
    ToolPanel: TPanel;
    DisplayMemo: TMemo;
    WSocketServer1: TWSocketServer;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure WSocketServer1ClientConnect(Sender: TObject;
      Client: TWSocketClient; Error: Word);
    procedure WSocketServer1ClientDisconnect(Sender: TObject;
      Client: TWSocketClient; Error: Word);
    procedure WSocketServer1BgException(Sender: TObject; E: Exception;
      var CanClose: Boolean);
  private
    FIniFileName: String;
    FInitialized: Boolean;
    procedure WMAppStartup(var Msg: TMessage); message WM_APPSTARTUP;
    procedure ClientBgException(Sender: TObject; E: Exception; var CanClose: Boolean);
    procedure WebSocketConnected(Sender: TObject; con: IWebSocketConnection);
    procedure WebSocketMessage(Sender: TObject; Msg: String);
  public
    procedure Display(Msg: String);
    property IniFileName: String read FIniFileName write FIniFileName;
  end;

var
  WebSocketForm: TWebSocketForm;

implementation

{$R *.DFM}

const
  SectionWindow      = 'WindowTcpSrv';
  KeyTop             = 'Top';
  KeyLeft            = 'Left';
  KeyWidth           = 'Width';
  KeyHeight          = 'Height';
  KeyPort            = 'Port';


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TWebSocketForm.FormCreate(Sender: TObject);
begin
  { Compute INI file name based on exe file name. Remove path to make it  }
  { go to windows directory.                                              }
  FIniFileName := GetIcsIniFileName;
  WSocketServer1.OnBgException := WSocketServer1BgException;
  WSocketServer1.OnClientConnect := WSocketServer1ClientConnect;
  WSocketServer1.OnClientDisconnect := WSocketServer1ClientDisconnect;
{$IFDEF DELPHI10_UP}
  // BDS2006 has built-in memory leak detection and display
  ReportMemoryLeaksOnShutdown := (DebugHook <> 0);
{$ENDIF}
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TWebSocketForm.FormShow(Sender: TObject);
var
  IniFile: TIcsIniFile;
  Port: Integer;
begin
  if not FInitialized then begin
    FInitialized := TRUE;

    { Fetch persistent parameters from INI file }
    IniFile      := TIcsIniFile.Create(FIniFileName);
    Width        := IniFile.ReadInteger(SectionWindow, KeyWidth,  Width);
    Height       := IniFile.ReadInteger(SectionWindow, KeyHeight, Height);
    Top          := IniFile.ReadInteger(SectionWindow, KeyTop,
                                        (Screen.Height - Height) div 2);
    Left         := IniFile.ReadInteger(SectionWindow, KeyLeft,
                                        (Screen.Width  - Width)  div 2);
    Port         := IniFile.ReadInteger(SectionWindow, KeyPort,  12345);
    IniFile.Free;
    DisplayMemo.Clear;
    { Delay startup code until our UI is ready and visible }
    PostMessage(Handle, WM_APPSTARTUP, Port, 0);
  end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TWebSocketForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
  IniFile: TIcsIniFile;
begin
  { Save persistent data to INI file }
  IniFile := TIcsIniFile.Create(FIniFileName);
  IniFile.WriteInteger(SectionWindow, KeyTop,         Top);
  IniFile.WriteInteger(SectionWindow, KeyLeft,        Left);
  IniFile.WriteInteger(SectionWindow, KeyWidth,       Width);
  IniFile.WriteInteger(SectionWindow, KeyHeight,      Height);
  IniFile.WriteInteger(SectionWindow, KeyPort, StrToInt(WSocketServer1.Port));
  IniFile.UpdateFile;
  IniFile.Free;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Display a message in our display memo. Delete lines to be sure to not     }
{ overflow the memo which may have a limited capacity.                      }
procedure TWebSocketForm.Display(Msg: String);
var
  I: Integer;
begin
  DisplayMemo.Lines.BeginUpdate;
  try
    if DisplayMemo.Lines.Count > 200 then begin
      for I := 1 to 50 do
        DisplayMemo.Lines.Delete(0);
    end;
    DisplayMemo.Lines.Add(Msg);
  finally
    DisplayMemo.Lines.EndUpdate;
    SendMessage(DisplayMemo.Handle, EM_SCROLLCARET, 0, 0);
  end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This is our custom message handler. We posted a WM_APPSTARTUP message     }
{ from FormShow event handler. Now UI is ready and visible.                 }
procedure TWebSocketForm.WMAppStartup(var Msg: TMessage);
var
  MyHostName: AnsiString;
begin
  Display(CopyRight);
  Display(OverbyteIcsWSocket.Copyright);
  Display(OverbyteIcsWSocketS.CopyRight);
  WSocket_gethostname(MyHostName);
  Display(' I am "' + String(MyHostName) + '"');
  Display(' IP: ' + LocalIPList.CommaText);
  WSocketServer1.Proto       := 'tcp';         { Use TCP protocol  }
  WSocketServer1.Port        := IntToStr(Msg.WParam);
  WSocketServer1.Addr        := '0.0.0.0';     { Use any interface }
  WSocketServer1.ClientClass := TTcpSrvClient; { Use our component }
  WSocketServer1.Banner      := ''; { Remove banner because we handle websocket handshake }
  WSocketServer1.Listen;                       { Start litening    }
  Display(' Waiting for clients at port ' + IntToStr(Msg.WParam) + '...');
  Display('');
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This handler is called when a new socket client is available,             }
{ at this moment it's not yet known if this is a proper websocket client.   }
procedure TWebSocketForm.WSocketServer1ClientConnect(
  Sender: TObject;
  Client: TWSocketClient;
  Error: Word);
begin
  with Client as TTcpSrvClient do begin
    Display('Client connected.' +
            ' Remote: ' + PeerAddr + '/' + PeerPort +
            ' Local: '  + GetXAddr + '/' + GetXPort);
    Display('There is now ' +
            IntToStr(TWSocketServer(Sender).ClientCount) +
            ' clients connected.');
    LineMode             := false;
    OnBgException        := ClientBgException;
    OnWebSocketMessage   := WebSocketMessage;
    OnWebSocketConnected := WebSocketConnected;
    ConnectTime          := Now;
  end;
  TWebSocketSocket.Create(TTcpSrvClient(Client));
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This handler is called after ClientConnect if the new client has passed   }
{ websockets handshake successfully; it's the place to check and to store   }
{ websockets-specific stuff, such as path (selector)                        }
procedure TWebSocketForm.WebSocketConnected(Sender: TObject; con: IWebSocketConnection);
var
  i: Integer;
  msg: String;
begin
  if Assigned(con) then
  begin
    Display('Websocket connected, headers follow:' + #13#10 + con.getHeaders.Text);
    i := con.getHeaders.IndexOfName('PATH');
    if i = -1 then
    begin
      msg := 'No selector in requested URL; must be /echo';
      Display(msg);
      con.sendString(AnsiString(msg));
      con.disconnect;
    end
    else
    if con.getHeaders.ValueFromIndex[i] <> '/echo' then
    begin
      msg := 'Unsupported selector "' + con.getHeaders.ValueFromIndex[i] + '" requested; must be /echo';
      Display(msg);
      con.sendString(AnsiString(msg));
      con.disconnect;
    end
    else
      con.sendString('Welcome to "echo" websockets service');
  end
  else
    (Sender as TWebSocketSocket).disconnect;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ When something arrived via a websocket, this handler is called with       }
{ the websocket as Sender, and raw data as Msg                              }
procedure TWebSocketForm.WebSocketMessage(Sender: TObject; Msg: String);
var
  L: Integer;
begin
  L := Length(Msg);
  if L > 80 then
  begin
    Display('Websocket message(' + IntToStr(L) + ' bytes)[suppressed]');
  end
  else
  begin
    Display('Websocket message(' + IntToStr(L) + ' bytes):' + UTF8Decode(RawByteString(Msg)));
  end;
  (Sender as TWebSocketSocket).getConnection.sendString(AnsiString(Msg + ' ' + DateTimeToStr(Now)));
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TWebSocketForm.WSocketServer1ClientDisconnect(
    Sender: TObject;
    Client: TWSocketClient;
    Error: Word);
begin
  with Client as TTcpSrvClient do begin
    Display('Client disconnecting: ' + PeerAddr + '   ' +
            'Duration: ' + FormatDateTime('hh:nn:ss',
            Now - ConnectTime));
    Display('There is now ' +
            IntToStr(TWSocketServer(Sender).ClientCount - 1) +
            ' clients connected.');
  end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This event handler is called when listening (server) socket experienced   }
{ a background exception. Should normally never occurs.                     }
procedure TWebSocketForm.WSocketServer1BgException(
  Sender       : TObject;
  E            : Exception;
  var CanClose : Boolean);
begin
  Display('Server exception occured: ' + E.ClassName + ': ' + E.Message);
  CanClose := FALSE;  { Hoping that server will still work ! }
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This event handler is called when a client socket experience a background }
{ exception. It is likely to occurs when client aborted connection and data }
{ has not been sent yet.                                                    }
procedure TWebSocketForm.ClientBgException(
  Sender       : TObject;
  E            : Exception;
  var CanClose : Boolean);
begin
  Display('Client exception occured: ' + E.ClassName + ': ' + E.Message);
  CanClose := TRUE;   { Goodbye client ! }
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}

end.


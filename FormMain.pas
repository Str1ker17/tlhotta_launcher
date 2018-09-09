unit FormMain;

interface

uses
  Windows, SysUtils, Forms, ShlObj, StdCtrls, ShellAPI, Registry,
  IniFiles, Controls, Classes, sCheckBox, sLabel,
  sSkinProvider, sSkinManager, sButton, sMemo, sBitBtn, sComboBox, sGroupBox,
  Graphics, ComCtrls, Buttons;

type
  TForm1 = class(TForm)
    Label1: TsLabel;
    Label2: TsLabel;
    Label3: TsLabel;
    Label4: TsLabel;
    GroupBoxDR: TsGroupBox;
    Memo1: TsMemo;
    CheckBoxDR: TsCheckBox;
    ComboBoxRMode: TsComboBox;
    Label6: TsLabel;
    Label7: TsLabel;
    GroupBoxRO: TsGroupBox;
    ComboBoxLng: TsComboBox;
    ButtonWriteRes: TsBitBtn;
    CheckBoxNSM: TsCheckBox;
    CheckBoxNA: TsCheckBox;
    sSkinProvider1: TsSkinProvider;
    ButtonToggle: TsButton;
    ButtonRun: TsButton;
    sSkinManager1: TsSkinManager;
    procedure FormCreate(Sender: TObject);
    procedure ButtonToggleClick(Sender: TObject);
    procedure ButtonRunClick(Sender: TObject);
    procedure ComboBoxLngChange(Sender: TObject);
    procedure ButtonWriteResClick(Sender: TObject);
    procedure ComboBoxRModeChange(Sender: TObject);
    procedure CheckBoxDRClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  MS_ENABLED = 3;
  MS_DISABLED = 2;
  MS_PARTIAL = 4;
  MS_CORRUPT = 5;
  MS_NONE = 1;
  GM_ENABLED = 1;
  GM_DISABLED = 0;
  GM_NONE = -1;

var
  Form1: TForm1; // form
  H: Cardinal; // handle of this app, used for ShellExecute
  a: Array of WideString; // mod files list
  l: Array of Array of WideString; // localized strings
  ln: Integer = 0; // current language ID
  ver: Integer; // version of mod
  ver_s: WideString; // version string
  status: Integer = 1; // status of mod
  reg: TRegistry; // Windows Registry Object
  dir_game: WideString; // game directory
  dir_ad: WideString; // user directory in the %APPDATA%
  dir_exe: WideString; // directory with this file, it can be places anywhere
  dir_appdata: WideString; // %APPDATA%
  Modes: array of Integer;
  // available screen resolutions, saved as width<<16 + height
  mode: Integer; // index of current video mode
  gunmod: Integer;
  debug: Boolean; // is debug mode active?

implementation

{$R *.dfm}

function posArray(a: array of Integer; v: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;

  for i := 0 to Length(a) - 1 do
  begin
    if (a[i] = v) then
    begin
      Result := i;
      break;
    end;
  end;
  posArray := Result;
end;

function GetSpecialPath(CSIDL: word): string;
var
  s: string;
begin
  SetLength(s, MAX_PATH);
  if not SHGetSpecialFolderPath(0, PChar(s), CSIDL, true) then
    s := '';
  Result := PChar(s);
end;

function ParamExists(const AParameter: String): Boolean;
// written by zumm
var
  i: Integer;
begin
  Result := False;

  for i := 1 to ParamCount do
  begin
    if ParamStr(i) = AParameter then
    begin
      Result := true;
      Exit;
    end;
  end;
end;

procedure logOutput(AMessage: WideString; ALevel: Integer; AMB: Boolean = true);
{
  0 - error
  1 - warning
  2 - info
  3 - debug (only in debug mode)
}
const
  Symbols: array [0 .. 3] of WideString = ('X', '!', 'i', 'D');
  MBL: array [0 .. 3] of Integer = (MB_ICONERROR, MB_ICONWARNING,
    MB_ICONINFORMATION, MB_OK);
begin
  if (debug) then
    Form1.Memo1.Lines.Add('[' + Symbols[ALevel] + '] ' + AMessage);
  if (ALevel in [0, 1, 2]) then
    MessageBox(H, PChar(AMessage), 'TLHOTTA Launcher', MBL[ALevel]);
end;

// load/save written by zumm, modified by Str1ker
procedure LoadSettings(AForms: array of TForm;
  AfName: WideString = '.\Settings.ini');
var
  Form, Component: Integer;
begin
  setCurrentDir(dir_exe);
  with TMemIniFile.Create(AfName) do
  begin
    try
      for Form := 0 to High(AForms) do
      begin
        if Assigned(AForms[Form]) then
        begin
          with AForms[Form] do
          begin
            for Component := 0 to ComponentCount - 1 do
            begin
              try

                if Components[Component] is TsComboBox then
                begin
                  with TsComboBox(Components[Component]) do
                  begin
                    ItemIndex := ReadInteger(AForms[Form].Name + '.TComboBox',
                      Name, ItemIndex);

                    if Assigned(OnChange) then
                    begin
                      OnChange(AForms[Form].Components[Component]);
                    end;
                  end;
                end;

                if Components[Component] is TEdit then
                begin
                  with TEdit(Components[Component]) do
                  begin
                    Text := ReadString(AForms[Form].Name + '.TEdit',
                      Name, Text);
                  end;
                end;

                if Components[Component] is TsCheckBox then
                begin
                  with TsCheckBox(Components[Component]) do
                  begin
                    Checked := ReadBool(AForms[Form].Name + '.TCheckBox',
                      Name, Checked);

                    if Assigned(OnClick) then
                    begin
                      OnClick(AForms[Form].Components[Component]);
                    end;
                  end;
                end;

                if Components[Component] is TRadioButton then
                begin
                  with TRadioButton(Components[Component]) do
                  begin
                    Checked := ReadBool(AForms[Form].Name + '.TRadioButton',
                      Name, Checked);

                    if Checked and Assigned(OnClick) then
                    begin
                      OnClick(AForms[Form].Components[Component]);
                    end;
                  end;
                end;
                // don't use TMemo there
                { if Components[Component] is TMemo then
                  begin
                  with TMemo(Components[Component]) do
                  begin
                  Text := ReadString(AForms[Form].Name+'.TMemo', Name, Text);
                  end;
                  end; }
              except
                // Errors Stub
              end;
            end;
          end;
        end;
      end;
    finally
      Free;
    end;
  end;
end;

procedure SaveSettings(AForms: array of TForm;
  AfName: WideString = '.\Settings.ini');
var
  Form, Component: Integer;
begin
  setCurrentDir(dir_exe);
  with TMemIniFile.Create(AfName) do
  begin
    try
      for Form := 0 to High(AForms) do
      begin
        if Assigned(AForms[Form]) then
        begin
          with AForms[Form] do
          begin
            for Component := 0 to ComponentCount - 1 do
            begin
              if Components[Component] is TsComboBox then
              begin
                with TsComboBox(Components[Component]) do
                begin
                  WriteInteger(AForms[Form].Name + '.TComboBox', Name,
                    ItemIndex);
                end;
              end;

              if Components[Component] is TEdit then
              begin
                with TEdit(Components[Component]) do
                begin
                  WriteString(AForms[Form].Name + '.TEdit', Name, Text);
                end;
              end;

              if Components[Component] is TsCheckBox then
              begin
                with TsCheckBox(Components[Component]) do
                begin
                  WriteBool(AForms[Form].Name + '.TCheckBox', Name, Checked);
                end;
              end;

              if Components[Component] is TRadioButton then
              begin
                with TRadioButton(Components[Component]) do
                begin
                  WriteBool(AForms[Form].Name + '.TRadioButton', Name, Checked);
                end;
              end;
              // don't use TMemo there
              { if Components[Component] is TMemo then
                begin
                with TMemo(Components[Component]) do
                begin
                WriteString(AForms[Form].Name+'.TMemo', Name, Text);
                end;
                end; }
            end;
          end;
        end;
      end;
    finally
      UpdateFile;
      Free;
    end;
  end;
end;

function getBIGStatus(AName: String): Integer;
begin
  setCurrentDir(dir_game);
  if (FileExists(AName + '.big')) then
    Result := 1
  else if (FileExists(AName + '.bis')) then
    Result := 0
  else
    Result := -1;
end;

function setBIGStatus(AName: String; AMode: Boolean): Boolean;
var
  st: Integer;
begin
  setCurrentDir(dir_exe);
  st := getBIGStatus(AName);
  if (st = -1) then
    Exit(False);
  if (Boolean(st) = AMode) then
    Exit(true);
  if (NOT AMode) then
    RenameFile(AName + '.big', AName + '.bis')
  else
    RenameFile(AName + '.bis', AName + '.big');
  Exit(true);
end;

procedure init();
var
  i: Integer;
begin
  dir_exe := getCurrentDir();
  SetLength(a, 7);
  SetLength(l, 2);
  a[0] := '_lasthope';
  a[1] := '_lasthopeart';
  a[2] := '_lasthopemaps';
  a[3] := '_lasthopeshaders';
  a[4] := '_lasthopesounds';
  a[5] := '_lasthopeterrain';
  a[6] := '__lasthopeart1.1';
  { data:='Not installed\Deactivated\Active\Partially active\';
    repeat
    until ; }

  // Russian (default)
  i := 0;
  SetLength(l[i], 60);
  l[i][1] := 'не установлен';
  l[i][2] := 'отключен';
  l[i][3] := 'активен';
  l[i][4] := 'частично активен';
  l[i][5] := 'повреждён';

  l[i][11] := 'Сайт разработчика';
  l[i][12] := 'Включить';
  l[i][13] := 'Выключить';
  l[i][14] := 'Удалить';
  l[i][15] := 'Удалить';

  l[i][21] := 'Запустить  оригинал';
  l[i][22] := l[i][21];
  l[i][23] := 'Запустить TLHOTTA';
  l[i][24] := 'Запустить как есть';
  l[i][25] := l[i][24];

  l[i][31] := 'Параметры запуска:';
  l[i][32] := 'Изменить разрешение:';
  l[i][33] := 'Статус мода:';
  l[i][34] := 'Статус игры:';
  l[i][35] := 'Версия игры:';
  l[i][36] := '-noshellmap';
  l[i][37] := '-noaudio';
  l[i][38] := 'Игра не установлена!';

  l[i][41] := 'Выключить видеозаставку в меню';
  l[i][42] := 'Выключить звук в игре';
  l[i][43] := 'Сделать разрешением по умолчанию';

  l[i][47] := 'Разрешение прописано в файл Options.ini';
  l[i][48] :=
    'Этот мод только для версии игры 1.06. Нажмите ''Да'', чтобы узнать, как обновить игру до 1.06.';

  l[i][51] := 'Стандартное';
  l[i][52] := 'Модернизированное';
  l[i][53] := 'Стандартное - без артиллерии, модернизированное - с артиллерией';

  // English
  i := 1;
  SetLength(l[i], 60);
  l[i][1] := 'Not installed';
  l[i][2] := 'Deactivated';
  l[i][3] := 'Active';
  l[i][4] := 'Partially active';
  l[i][5] := 'Corrupted';

  l[i][11] := 'bfme-modding.ru';
  l[i][12] := 'Enable';
  l[i][13] := 'Disable';
  l[i][14] := 'Remove';
  l[i][15] := 'Remove';

  l[i][21] := 'Run original';
  l[i][22] := l[i][21];
  l[i][23] := 'Run TLHOTTA';
  l[i][24] := 'Run as is';
  l[i][25] := l[i][24];

  l[i][31] := 'Running options:';
  l[i][32] := 'Run with different resolution:';
  l[i][33] := 'Mod Status:';
  l[i][34] := 'Game Status:';
  l[i][35] := 'Game Version:';
  l[i][36] := '-noshellmap';
  l[i][37] := '-noaudio';
  l[i][38] := 'Game not found!';

  l[i][41] := 'Disable background movie';
  l[i][42] := 'Disable in-game audio at all';
  l[i][43] := 'Set this resolution as default';

  l[i][47] := 'Resolution set to Options.ini';
  l[i][48] :=
    'Your game version is not 1.06! This mod works only on BfME 1.06. ' +
    'Click ''Yes'' to know how to upgrade your game.';

  l[i][51] := 'Standard';
  l[i][52] := 'Modern';
  l[i][53] := 'Without / with artillery';

  // looking for the installed game

  dir_appdata := GetSpecialPath(CSIDL_APPDATA); // get %APPDATA%

  if (FileExists('lotrbfme2.exe')) then
  begin
    dir_game := dir_exe;
  end
  else
  begin
    // if the gamedir is not current, look into registry
    reg := TRegistry.Create;
    reg.RootKey := HKEY_LOCAL_MACHINE;
    reg.OpenKeyReadOnly
      ('SOFTWARE\Electronic Arts\The Battle for Middle-earth II');
    dir_game := reg.ReadString('Install Dir');
    reg.CloseKey;
    reg.Free;
  end;

  // get leaf in appdata from registry
  reg := TRegistry.Create;
  reg.RootKey := HKEY_LOCAL_MACHINE;
  reg.OpenKeyReadOnly
    ('SOFTWARE\Electronic Arts\Electronic Arts\The Battle for Middle-earth II');
  dir_ad := reg.ReadString('UserDataLeafName');
  ver := reg.ReadInteger('Version');
  reg.CloseKey;
  reg.Free;

  // a bit rude way to get gamever string
  // ver_s := IntToHex(ver, 4);
  // ver := StrToInt(ver_s);
  ver_s := IntToStr(ver div 65536) + '.0' + IntToStr(ver mod 65536);

  // show data in memo for debug
  logOutput('GAMEDIR=' + dir_game, 3, False);
  logOutput('APPDATA=' + dir_appdata + '\' + dir_ad, 3, False);
  logOutput('GAMEVER=' + ver_s, 3, False);

end;

procedure loadLanguage(ln_id: Integer);
// only replaces!
begin
  ln := ln_id;
  with Form1 do
  begin
    GroupBoxDR.Caption := l[ln][32];
    GroupBoxRO.Caption := l[ln][31];
    Label1.Caption := l[ln][33];
    Label3.Caption := l[ln][34];
    Label6.Caption := l[ln][35];
    // Label8.Caption:=l[ln][36];
    CheckBoxNSM.Caption := l[ln][36];
    // Label9.Caption:=l[ln][37];
    CheckBoxNA.Caption := l[ln][37];
    ButtonToggle.Caption := l[ln][status + 10];
    ButtonRun.Caption := l[ln][status + 20];
    Label2.Caption := l[ln][status];
    Label7.Caption := ver_s;
    CheckBoxNSM.Hint := l[ln][41];
    CheckBoxNA.Hint := l[ln][42];
    ButtonWriteRes.Hint := l[ln][43];
  end;
end;

function getStatus(): Integer;
var
  i, r, c, b0, b1: Integer;
begin
  b0 := 0; // ready big files count
  b1 := 0; // disabled (renamed) big files
  Result := MS_NONE; // status of mod
  setCurrentDir(dir_game);
  c := Length(a);
  for i := 0 to c - 1 do
  begin
    r := getBIGStatus(a[i]);
    if (r = 0) then
      b0 := b0 + 1
    else if (r = 1) then
      b1 := b1 + 1;
  end;
  if (b1 = c) then
    Result := MS_ENABLED
  else if (b0 = c) then
    Result := MS_DISABLED
  else if (b0 + b1 = c) then
    Result := MS_PARTIAL
  else if (b0 + b1 > 0) then
    Result := MS_CORRUPT;

end;

{function getGMStatus(): Integer;
var
  r1, r2: Integer;
begin
  setCurrentDir(dir_exe);
  r1 := getBIGStatus('_lasthopese'); // gm off = org on
  r2 := getBIGStatus('_lasthopene'); // org off = gm on
  if ((r1 = -1) AND (r2 = -1)) then
    Exit(GM_NONE);
  if (r2 = 0) then
    Exit(GM_ENABLED);
  Exit(GM_DISABLED);
end;}

{function setGMStatus(AMode: Boolean): Boolean;
var
  r: Integer;
begin
  r := getGMStatus();
  if(r = GM_NONE) then exit(false);
  if(Boolean(r) = AMode) then exit(true);
  if(AMode) then begin
    RenameFile(a[0] + '.big', '_lasthopene.bis');
    RenameFile('_lasthopese.bis', a[0] + '.big');
  end
  else begin
    RenameFile(a[0] + '.big', '_lasthopese.bis');
    RenameFile('_lasthopene.bis', a[0] + '.big');
  end;
  exit(true);
end;}

procedure getResolutions();
var
  ModeNumber, ModeVal: Integer;
  MyMode: TDeviceModeW;
  Check: Boolean;
begin
  ModeNumber := 0;
  Check := true;
  while (Check) do
  begin
    Check := EnumDisplaySettings(nil, ModeNumber, MyMode);
    ModeVal := MyMode.dmPelsWidth * 65536 + MyMode.dmPelsHeight;
    if (posArray(Modes, ModeVal) = -1) then
    begin
      SetLength(Modes, Length(Modes) + 1);
      Modes[Length(Modes) - 1] := ModeVal;
    end;
    Inc(ModeNumber);
  end;
end;

procedure fixLPos;
begin
  with Form1 do
  begin
    // locate game status to center
    Label3.Left := (Form1.Width - (Label3.Width + Label4.Width + 4)) div 2;
    // make second label relative to first label
    Label2.Left := Label1.Left + Label1.Width + 4;
    Label4.Left := Label3.Left + Label3.Width + 4;
    Label7.Left := Label6.Left + Label6.Width + 4;
  end;
end;

procedure TForm1.ButtonWriteResClick(Sender: TObject);
var
  ini: TMemIniFile;
  list: TStrings;
  s: WideString;
begin
  try
    if not(setCurrentDir(dir_appdata + '\' + dir_ad)) then
      raise Exception.Create('cd to ' + dir_appdata + '\' + dir_ad +
        ' failed!');
    list := TStringList.Create;
    list.LoadFromFile('Options.ini');
    list.Insert(0, '[Main]');
    list.SaveToFile('OptionsFix.ini');
    ini := TMemIniFile.Create('OptionsFix.ini');
    s := IntToStr(Modes[mode] div 65536) + ' ' +
      IntToStr(Modes[mode] mod 65536);
    ini.WriteString('Main', 'Resolution', s);
    ini.UpdateFile;
    ini.Free;
    list.LoadFromFile('OptionsFix.ini');
    list.Delete(0);
    list.SaveToFile('Options.ini');
    list.Free;
    DeleteFile('OptionsFix.ini');
    // TODO: replace Memo by MessageBox'es
    logOutput(l[ln][47] + ': ' + s, 2);
  except
    on e: Exception do
      logOutput(e.Message, 1);
  end;
end;

procedure TForm1.ButtonToggleClick(Sender: TObject);
var
  i, c: Integer;
begin
  c := Length(a);
  setCurrentDir(dir_game);
  case status of

    MS_NONE:
      ShellExecute(H, 'open', 'http://bfme-modding.ru/', '', '', SW_RESTORE);

    MS_DISABLED:
      begin

        for i := 0 to c - 1 do
        begin
          setBIGStatus(a[i], true);
        end;

      end;

    MS_ENABLED:
      begin

        for i := 0 to c - 1 do
        begin
          setBIGStatus(a[i], False);
        end;

      end;

    MS_PARTIAL, MS_CORRUPT:
      begin

        for i := 0 to c - 1 do
        begin
          if (FileExists(a[i] + '.big')) then
            DeleteFile(a[i] + '.big');
          if (FileExists(a[i] + '.bis')) then
            DeleteFile(a[i] + '.bis');
        end;

      end;

  end;

  // refreshing
  status := getStatus();
  //gunmod := getGMStatus();
  Form1.ButtonToggle.Caption := l[ln][status + 10];
  Form1.Label2.Caption := l[ln][status];
  //Form1.CheckBoxGM.Enabled := ((gunmod <> GM_NONE) AND (status = MS_ENABLED));
  //Form1.CheckBoxGM.Checked := (gunmod = GM_ENABLED);

  setCurrentDir(dir_game);
  if (NOT FileExists('lotrbfme2.exe')) then
  begin
    Form1.ButtonRun.Enabled := False;
    Form1.ButtonRun.Caption := l[ln][38];
  end
  else
  begin
    Form1.ButtonRun.Enabled := true;
    Form1.ButtonRun.Caption := l[ln][status + 20];
  end;

end;

procedure TForm1.ButtonRunClick(Sender: TObject);
var
  params: WideString;
  xres, yres: Integer;
begin
  setCurrentDir(dir_game);
  if (status = MS_ENABLED) then
    params := params + '-mod "lasthopeasset_scarlet.big" ';
  if (CheckBoxDR.Checked) then
  begin
    xres := Modes[mode] div 65536;
    yres := Modes[mode] mod 65536;
    params := params + '-xres ' + IntToStr(xres) + ' -yres ' +
      IntToStr(yres) + ' ';
  end;
  if (CheckBoxNSM.Checked) then
    params := params + '-noshellmap ';
  if (CheckBoxNA.Checked) then
    params := params + '-noaudio ';
  if (NOT FileExists('lotrbfme2.exe')) then
  begin
    ButtonRun.Enabled := False;
    ButtonRun.Caption := l[ln][38];
  end
  else
  begin
    logOutput('Running ' + dir_game + 'lotrbfme2.exe ' + params + '...',
      3, False);
    ShellExecute(H, 'open', 'lotrbfme2.exe', PChar(params), PChar(dir_game),
      SW_SHOWNORMAL);
  end;

end;

procedure TForm1.CheckBoxDRClick(Sender: TObject);
begin
  ComboBoxRMode.Enabled := CheckBoxDR.Checked;
  ButtonWriteRes.Enabled := CheckBoxDR.Checked;
end;

procedure TForm1.ComboBoxRModeChange(Sender: TObject);
begin
  mode := ComboBoxRMode.ItemIndex;
end;

procedure TForm1.ComboBoxLngChange(Sender: TObject);
begin
  loadLanguage(ComboBoxLng.ItemIndex);
  fixLPos;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveSettings([Form1]);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  H := Handle; // handle is a current window
  debug := ParamExists('-debug');

  Form1.Memo1.Visible := debug;

  // if (ParamExists('-fskin')) then
  // sSkinManager1.SkinName := 'Graphite (internal)';

  init();
  loadLanguage(ln);

  // check game version
  if (ver_s <> '1.06') then
  begin
    i := MessageBox(H, PChar(l[ln][48]), 'TLHOTTA Launcher',
      MB_YESNO OR MB_ICONERROR);
    if (i = 6) then
      ShellExecute(H, 'open', 'http://bfme-modding.ru/faq/0-1#2', '', '',
        SW_SHOWNORMAL);
  end;

  // get mod info
  status := getStatus();
  Form1.ButtonToggle.Caption := l[ln][status + 10];
  Form1.Label2.Caption := l[ln][status];
  //Form1.CheckBoxGM.Enabled := (status = 3);

  // check for game exe
  setCurrentDir(dir_game);
  if (NOT FileExists('lotrbfme2.exe')) then
  begin
    Form1.ButtonRun.Enabled := False;
    Form1.ButtonRun.Caption := l[ln][38];
    logOutput(l[ln][38], 1);
  end
  else
  begin
    Form1.ButtonRun.Enabled := true;
    Form1.ButtonRun.Caption := l[ln][status + 20];
  end;
  setCurrentDir(dir_exe);

  // load all valid resolutions to combobox
  getResolutions();
  for i := 0 to Length(Modes) - 1 do
  begin
    ComboBoxRMode.Items.Add(IntToStr(Modes[i] div 65536) + 'x' +
      IntToStr(Modes[i] mod 65536));
  end;

  mode := posArray(Modes, Screen.Width * 65536 + Screen.Height);
  ComboBoxRMode.ItemIndex := mode;

  // fix status labels alignment
  fixLPos();

  // load visual components settings
  LoadSettings([Form1]);

  // set gunmod status
  //gunmod := getGMStatus();
  //Form1.CheckBoxGM.Enabled := ((gunmod <> GM_NONE) AND (status = MS_ENABLED));
  //Form1.CheckBoxGM.Checked := (gunmod = GM_ENABLED);

end;

end.
